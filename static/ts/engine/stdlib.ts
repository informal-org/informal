export const BUILTIN_FN = {
    "TRIM": {
        "description": "Remove spaces from both ends of text.",
        "args": ["text"],
        "fn": function(text: string) {
            return text.trim();
        }
    },
    "LOWER_CASE": {
        "description": "Convert text to upper case.",
        "args": ["text"],
        "fn": function(text: string) {
            return text.toLowerCase();
        }
    },
    "UPPER_CASE": {
        "description": "Convert text to upper case.",
        "args": ["text"],
        "fn": function(text: string) {
            return text.toUpperCase();
        }
    },
    // // TITLE CASE?

    // "LEFT": {},
    // "MID": {},
    // "RIGHT": {},
    // "JOIN": {}, // Text join

    // "LENGTH": {},   // Count?

    // "FIND": {}, // index of.

    // "REPLACE": {},
    
    // "ABS": {},

    // "SUM": {},
    // "PRODUCT": {},
    // "SQRT": {},
    // "MOD": {},
    // "AVERAGE": {},

    // "ROUND": {},
    // "ROUND_DOWN": {},
    // "ROUND_UP": {},

    // "RANDOM": {},    // Between 0 & 1

    // // Sin, cos, tan. They can use table lookups for these. 
    // // "LOG": {},   // mathematical log. not logging log.

    // // "COUNT": {},

    // "MAX": {},
    // "MIN": {},

    // // todo: HTTP Request

    // // First - first element of a list
    // // Reverse - reverse order of a list

    // // Group - group like values into sub lists

    // // At index. 
    // // Range

    // // Ajax - get
    // // Ajax - post

};

console.log(BUILTIN_FN);
console.log(Object.keys(BUILTIN_FN));