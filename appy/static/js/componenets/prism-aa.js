// Based on prism Python highlighting
Prism.languages.appassembly = {
	'comment': [
		{
			pattern: /(^|[^\\])\/\*[\s\S]*?(?:\*\/|$)/,
			lookbehind: true
		},
		{
			pattern: /(^|[^\\:])\/\/.*/,
			lookbehind: true,
			greedy: true
		}
	],
	'string': {
		pattern: /(?:[rub]|rb|br)?("|')(?:\\.|(?!\1)[^\\\r\n])*\1/i,
		greedy: true
	},
	'function': {
		pattern: /((?:^|\s)def[ \t]+)[a-zA-Z_]\w*(?=\s*\()/g,
		lookbehind: true
	},
	'keyword': /\b(?:and|as|in|is|not|or)\b/,
	'builtin': /\b(?:all|any|bool|dict|float|int|list|max|min|next|object|pow|range|reduce|round|set|slice|str|sum|super)\b/,
	'boolean': /\b(?:true|false|null)\b/,
	'number': /(?:\b(?=\d)|\B(?=\.))(?:0[bo])?(?:(?:\d|0x[\da-f])[\da-f]*\.?\d*|\.\d+)(?:e[+-]?\d+)?j?\b/i,
	'operator': /[-+%=]=?|!=|\*\*?=?|\/\/?=?|<[<=>]?|>[=>]?|[&|^~]/,
	'punctuation': /[{}[\];(),.:]/
};

//Prism.languages.appassembly['string-interpolation'].inside['interpolation'].inside.rest = Prism.languages.appassembly;
Prism.languages.aa = Prism.languages.appassembly;
