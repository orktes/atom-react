snippets:
	curl -O "https://raw.githubusercontent.com/orktes/atom-react/master/snippets/JavaScript%20(JSX).cson"
	cson2json JavaScript%20\(JSX\).cson > _data/snippets.json
	rm JavaScript%20\(JSX\).cson
	curl -O "https://raw.githubusercontent.com/orktes/atom-react/master/grammars/JavaScript%20(JSX).cson"
	curl -O "https://raw.githubusercontent.com/atom/language-javascript/master/grammars/javascript.cson"
	cson2json javascript.cson > javascript.json
	cson2json JavaScript%20\(JSX\).cson > jsx.json
	rm JavaScript%20\(JSX\).cson
	rm javascript.cson
	node generate_tokens.js
	rm javascript.json
	rm jsx.json
	curl -o assets/css/atom-dark-syntax.css http://atom.github.io/highlights/examples/atom-dark.css
