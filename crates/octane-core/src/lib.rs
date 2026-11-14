use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{collections::{BTreeMap, BTreeSet}, fs::{self, File}, io::{Read, Write}, path::{Path, PathBuf}};

pub const MAX_FILE_BYTES: u64 = 256 * 1024 * 1024;
pub const MAX_TOTAL_BYTES: u64 = 2 * 1024 * 1024 * 1024;
pub const MAX_FILES: usize = 2048;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileRecord { pub path: String, pub extension: String, pub bytes: u64, pub sha256: String }
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct FileError { pub path: String, pub error: String }
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Report {
    pub schema_version: u32,
    pub files: Vec<FileRecord>,
    pub errors: Vec<FileError>,
    pub groups: BTreeMap<String, usize>,
    pub duplicate_sets: Vec<Vec<String>>,
    pub total_bytes: u64,
}

fn hash_file(path: &Path, budget: u64) -> Result<(u64, String), String> {
    let mut f = File::open(path).map_err(|e| e.to_string())?;
    let before = f.metadata().map_err(|e| e.to_string())?;
    if !before.is_file() { return Err("Not a regular file".into()); }
    if before.len() > MAX_FILE_BYTES || before.len() > budget { return Err("File or batch byte limit exceeded".into()); }
    let mut hash = Sha256::new();
    let mut buffer = [0u8; 65536];
    let mut size = 0u64;
    loop {
        let n = f.read(&mut buffer).map_err(|e| e.to_string())?;
        if n == 0 { break; }
        size += n as u64;
        if size > MAX_FILE_BYTES || size > budget { return Err("File grew beyond byte limit".into()); }
        hash.update(&buffer[..n]);
    }
    let after = f.metadata().map_err(|e| e.to_string())?;
    if size != before.len() || before.len() != after.len() || before.modified().ok() != after.modified().ok() {
        return Err("File changed during analysis; retry with stable input".into());
    }
    Ok((size, format!("{:x}", hash.finalize())))
}

pub fn analyze(paths: Vec<PathBuf>) -> Result<Report, String> {
    if paths.len() > MAX_FILES { return Err(format!("Choose at most {MAX_FILES} files")); }
    let mut report = Report { schema_version: 1, ..Report::default() };
    let mut seen = BTreeSet::new();
    let mut hashes: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for input in paths {
        let result = (|| {
            let path = fs::canonicalize(&input).map_err(|e| e.to_string())?;
            if !seen.insert(path.clone()) { return Ok(None); }
            let (bytes, sha256) = hash_file(&path, MAX_TOTAL_BYTES - report.total_bytes)?;
            let extension = path.extension().and_then(|s| s.to_str()).filter(|s| !s.is_empty()).unwrap_or("(none)").to_lowercase();
            Ok(Some(FileRecord { path: path.to_string_lossy().into_owned(), extension, bytes, sha256 }))
        })();
        match result {
            Ok(Some(record)) => {
                report.total_bytes += record.bytes;
                *report.groups.entry(record.extension.clone()).or_default() += 1;
                hashes.entry(record.sha256.clone()).or_default().push(record.path.clone());
                report.files.push(record);
            }
            Ok(None) => (),
            Err(error) => report.errors.push(FileError { path: input.to_string_lossy().into_owned(), error }),
        }
    }
    report.duplicate_sets = hashes.into_values().filter(|paths| paths.len() > 1).collect();
    Ok(report)
}

pub fn export_new(report: &Report, path: &Path) -> Result<(), String> {
    // create_new is atomic and prevents replacing any existing input or report.
    let data = serde_json::to_vec_pretty(report).map_err(|e| e.to_string())?;
    let mut output = File::options().write(true).create_new(true).open(path).map_err(|e| e.to_string())?;
    output.write_all(&data).and_then(|_| output.sync_all()).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test] fn sample_contract_and_known_hash() {
        let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures");
        let mut paths: Vec<_> = fs::read_dir(dir).unwrap().map(|e| e.unwrap().path()).collect();
        paths.sort();
        let r = analyze(paths).unwrap();
        assert_eq!((r.files.len(), r.groups.len(), r.duplicate_sets.len(), r.errors.len()), (8,6,1,0));
        assert_eq!(r.files.iter().find(|f| f.path.ends_with("hello.txt")).unwrap().sha256,
            "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03");
    }
    #[test] fn dedup_paths_and_report_missing_files() {
        let dir = tempfile::tempdir().unwrap();
        let p = dir.path().join("A.TXT"); fs::write(&p, "same").unwrap();
        let r = analyze(vec![p.clone(), p, dir.path().join("missing"), dir.path().to_owned()]).unwrap();
        assert_eq!(r.files.len(), 1); assert_eq!(r.errors.len(), 2); assert_eq!(r.groups["txt"], 1);
    }
    #[test] fn export_never_overwrites_and_roundtrips() {
        let dir = tempfile::tempdir().unwrap(); let p = dir.path().join("report.json");
        let r = analyze(vec![]).unwrap(); export_new(&r, &p).unwrap();
        let parsed: Report = serde_json::from_slice(&fs::read(&p).unwrap()).unwrap();
        assert_eq!(parsed.schema_version, 1); assert!(export_new(&r, &p).is_err());
    }
    #[test] fn enforces_count_and_file_limits() {
        assert!(analyze(vec![PathBuf::new(); MAX_FILES+1]).is_err());
        let dir = tempfile::tempdir().unwrap(); let p = dir.path().join("large");
        File::create(&p).unwrap().set_len(MAX_FILE_BYTES+1).unwrap();
        assert_eq!(analyze(vec![p]).unwrap().errors.len(), 1);
    }
}
