import test from 'node:test';
import assert from 'node:assert/strict';
import {formatBytes,summary} from '../ui/format.mjs';
test('byte boundaries',()=>{assert.equal(formatBytes(0),'0 B');assert.equal(formatBytes(1024),'1.0 KiB');assert.equal(formatBytes(1048576),'1.0 MiB')});
test('summary uses real report counts',()=>{assert.deepEqual(summary({files:[1,2],groups:{txt:2},duplicateSets:[[1,2]],totalBytes:8}),[2,1,1,'8 B'])});
