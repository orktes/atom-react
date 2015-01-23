var fs = require('fs');
var _ = require('lodash');

var HighLights = require('highlights');

var highlighter = new HighLights();

var snippetsBase = require('./_data/snippets.json');
var snippets = snippetsBase['.source.js'];

function zeroFill( number, width )
{
  width -= number.toString().length;
  if ( width > 0 )
  {
    return new Array( width + (/\./.test( number ) ? 2 : 1) ).join( '0' ) + number;
  }
  return number + ""; // always return a string
}

highlighter.registry.loadGrammarSync('./javascript.json');
highlighter.registry.loadGrammarSync('./jsx.json');

var i = 0;
for (var key in snippets) {
  var snippet = snippets[key];
  snippet.html = highlighter.highlightSync({
    fileContents: snippet.body.replace(/\t/g, '  '),
    scopeName: 'source.js.jsx'
  });
}

fs.writeFileSync('./_data/snippets.json', JSON.stringify(snippetsBase, null, 2));
