export function formatBytes(n) { return n < 1024 ? `${n} B` : n < 1048576 ? `${(n/1024).toFixed(1)} KiB` : `${(n/1048576).toFixed(1)} MiB`; }
export function summary(report) { return [report.files.length, Object.keys(report.groups).length, report.duplicateSets.length, formatBytes(report.totalBytes)]; }
