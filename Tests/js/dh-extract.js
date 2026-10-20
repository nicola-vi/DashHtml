/* Loads named runtime functions from the shipped PowerShell here-string fragments
 * (DashHtml/Private/Get-DhJs*.ps1) so node tests exercise production code.
 *
 *   const { load } = require('./dh-extract');
 *   const { dhNavFit } = load('Get-DhJsNav.ps1', ['dhNavFit']);
 *
 * Finds `  function Name(` at the runtime's two-space indent and takes everything up to
 * the first line that closes it at that indent. Throws when a function is missing, so
 * a rename in the runtime fails the test instead of silently skipping it.
 */
'use strict';
const fs   = require('fs');
const path = require('path');

const PRIVATE = path.join(__dirname, '..', '..', 'DashHtml', 'Private');

function extractSource(file, name) {
  const src = fs.readFileSync(path.join(PRIVATE, file), 'utf8');
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const rx  = new RegExp('^  (?:function ' + esc + '\\s*\\(|\\w+\\.prototype\\.' + esc + '\\s*=\\s*function\\s*\\().*?^  \\};?\\s*$', 'ms');
  const m = rx.exec(src);
  if (!m) throw new Error(`function ${name} not found in ${file}`);
  return m[0];
}

/* Returns { name: fn } for plain functions. `scope` supplies globals the functions use. */
function load(file, names, scope) {
  scope = scope || {};
  const keys = Object.keys(scope);
  const body = names.map(n => extractSource(file, n)).join('\n') + '\nreturn {' + names.join(',') + '};';
  return new Function(...keys, body)(...keys.map(k => scope[k]));
}

/* For `TableEngine.prototype.X = function` methods: returns { X: fn } to call with .call(fakeThis, ...). */
function loadMethods(file, names, scope) {
  scope = scope || {};
  const keys = Object.keys(scope);
  const body = 'var TableEngine = function () {};\n' + names.map(n => extractSource(file, n)).join('\n') +
               '\nreturn {' + names.map(n => `${n}: TableEngine.prototype.${n}`).join(',') + '};';
  return new Function(...keys, body)(...keys.map(k => scope[k]));
}

/* A top-level `  var NAME = ...;` (one line, or a literal closed by `  };` at the same indent). */
function extractVar(file, name) {
  const src = fs.readFileSync(path.join(PRIVATE, file), 'utf8');
  const lines = src.split('\n');
  const start = lines.findIndex(l => l.startsWith('  var ' + name + ' ='));
  if (start < 0) throw new Error(`var ${name} not found in ${file}`);
  if (/;\s*(\/\*.*\*\/)?\s*$/.test(lines[start])) return lines[start];
  let end = start + 1;
  while (end < lines.length && !/^  \};\s*$/.test(lines[end])) end++;
  return lines.slice(start, end + 1).join('\n');
}

/* Plain functions plus top-level vars: loadWith('File.ps1', { vars: ['FMT'], fns: ['esc'] }, scope). */
function loadWith(file, spec, scope) {
  scope = scope || {};
  const keys = Object.keys(scope);
  const vars = spec.vars || [], fns = spec.fns || [];
  const body = vars.map(n => extractVar(file, n)).concat(fns.map(n => extractSource(file, n))).join('\n') +
               '\nreturn {' + vars.concat(fns).join(',') + '};';
  return new Function(...keys, body)(...keys.map(k => scope[k]));
}

module.exports = { extractSource, extractVar, load, loadWith, loadMethods };