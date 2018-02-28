
export const BUILTIN_FN = {
    "TRIM": {
        "description": "Remove spaces from both ends of text.",
        "args": ["text"],
        "fn": function(text: string) {
            return text.trim();
        }
    },
    "LOWER_CASE": {
        "description": "Convert text to lower case.",
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
    "FIRST": {
        "description": "Extracts left most letters or elements from text or list.",
        "args": ["collection", "length"],
        "defaults": ["", 1],
        "fn": function(collection: any, length: number){
            if(Array.isArray(collection)){
                return collection.slice(0, length);
            }
            // Else, it's a string (hopefully).
            return collection.toString().substr(0, length) // Use substr for length, substring for end index.
        }
    },
    "SLICE": {
        "description": "Extracts letters or elements from the middle of a text or list.",
        "args": ["collection", "start", "end", "step"],
        "defaults": ["", 0, "", 1],
        "fn": function(collection: any, start: number, end: number, step: any){
            if(start == undefined || start == ""){
                start = 0;
            }
            if(end == undefined || end == ""){
                end = collection.length;
            }
            // https://codereview.stackexchange.com/questions/57268
            var slice = collection.slice || Array.prototype.slice;
            var sliced = slice.call(collection, start, end);
            var result, length, i;
            if (!step) {
                return sliced;
            }
            result = [];
            length = sliced.length;
            i = (step > 0) ? 0 : length - 1;
            for (; i < length && i >= 0; i += step) {
                result.push(sliced[i]);
            }
            return typeof collection == "string" ? result.join("") : result;
        }
    },
    "LAST": {
        "description": "Extracts letters or elements from the end of a text or list.",
        "args": ["collection", "length"],
        "defaults": ["", 1],
        "fn": function(collection: any, length: number){
            if(Array.isArray(collection)){
                return collection.slice(-1 * length);
            }
            if(length > collection.length){
                length = collection.length;
            }
            // Else, it's a string (hopefully).
            return collection.toString().substr(collection.length - length) // Use substr for length, substring for end index.
        }
    },
    "SPLIT": {
        "description": "Split a list or text into separate lists by a certain element",
        "args": ["collection", "separator"],
        "fn": function(collection: any, separator: string){
            if(Array.isArray(collection)){
                let result = [];
                let subResult = []
                collection.forEach((elem) => {
                    if(elem === separator){
                        // Then split. Don't add it to result.
                        result.push(subResult);
                    } else {
                        subResult.push(elem);
                    }
                });
                result.push(subResult);
                return result;
            }
            return collection.split(separator);
        }
    },
    "JOIN": {      // TODO - confusion with JOIN in database parlance?
        "description": "Join a list into a string with the separator (like a comma) in between elements.",
        "args": ["collection", "separator"],
        "fn": function(collection: any, separator: string){
            return collection.join(separator);
        }
    }, 
    "LENGTH": { // TODO: Rename all string to text.
        "description": "Get the length of a string or list.",
        "args": ["collection"],
        "fn": function(collection: any){
            return collection.length;
        }
    }, 
    "FIND_INDEX": {
        "description": "Find the index of an element in a string or list.",
        "args": ["collection", "element"],
        "fn": function(collection: any, element: any){
            return collection.indexOf(element);
        }
    },
    "REPLACE_ALL": {
        "description": "Replace all instances of the element with substitution.",
        "args": ["collection", "search", "substitution"],
        "fn": function(collection: any, search: any, substitution: any){
            if(Array.isArray(collection)){
                let result = collection.map((el) => {
                    return el === search ? substitution : el;
                });
                return result;
            }
            return collection.replace(search, substitution);
        }
    },
    "ABSOLUTE_VALUE": {
        "description": "Get the absolute value of a number.",
        "args": ["value"],
        "fn": function(value: number){
            return Math.abs(value);
        }
    },
    "SUM": {
        "description": "Sum values in a list.",
        "args": ["list"],
        "fn": function(list: Array){
            let sum = 0;
            if(list){
                list.forEach((el) => {
                    sum += el;
                });                
            }
            return sum;
        }
    },
    "PRODUCT": {
        "description": "Get the product of all value in a list.",
        "args": ["list"],
        "fn": function(list: number){
            let prod = 0;
            if(list) {
                list.forEach((el) => {
                    prod *= el;
                })
    
            }
            return prod;
        }
    },
    "SQUARE_ROOT": {
        "description": "Get the square root of a number.",
        "args": ["value"],
        "fn": function(value: number){
            return Math.sqrt(value);
        }
    },
    "MODULO": {
        "description": "Get the remainder of a division.",
        "args": ["value", "modulus"],
        "fn": function(value: number, modulus: number){
            return value % modulus;
        }
    },
    "AVERAGE": {
        "description": "Retrieve the average of the list.",
        "args": ["list"],
        "fn": function(list: Array){
            let sum = 0;
            if(list){
                list.forEach((el) => {
                    sum += el;
                })
                if(list.length > 0){
                    return sum / list.length;
                }    
            }
            // TODO: What to return else?
            return 0;
        }
    },
    "INDEX": {
        "description": "Get element at an index for string or list.",
        "args": ["collection", "index"],
        "fn": function(collection: any, index: number){
            return collection[index];
        }
    },
    "COUNT": {
        "description": "Count the number of times an element appears in a list.",
        "args": ["list", "element"],
        "fn": function(list: Array, element: any){
            let count = 0;
            list.forEach((el) => {
                if(el == element){
                    count++;
                }
            })
            return count;
        }
    },
    "DISTINCT": {
        "description": "Retrieve the distinct elements in a list.",
        "args": ["list"],
        "fn": function(list: Array){
            return new Array(new Set(list));
        }
    },
    "MAX": {
        "description": "Find the maximum value in a list.",
        "args": ["list"],
        "fn": function(list: Array){
            return Math.max(...list);
        }
    },
    "MIN": {
        "description": "Find the minimum value in a list.",
        "args": ["list"],
        "fn": function(list: Array){
            return Math.min(...list);
        }
    },        
    "REVERSE": {
        "description": "Reverse a list.",
        "args": ["list"],
        "fn": function(list: Array){
            return list.reverse();
        }
    },   
    "SORT": {  // TODO: Table sort key
        "description": "Sort a list.",
        "args": ["list"],
        "fn": function(list: Array){
            return list.sort();
        }
    },
    "RANGE": {
        "description": "Generate a list of numbers in a given range.",
        "args": ["start", "stop", "step"],
        "fn": function(start: number, stop: number, step: number){
            if(start == undefined || start == ""){
                start = 0;
            }
            // Prevent infinite loop
            if(stop == undefined || stop == ""){
                stop = start;
            }
            if(step == undefined || step == "" || step <= 0){
                step = 1;
            }
            // TODO: Defaults for start, stop, step.
            let result = [];
            for(var i = start; i < stop; i += step){
                result.push(i);
            }
            return result;
        }
    },
};

// TODO: Function names sorted alphabetically in display.


    // "ROUND": {},
    // "ROUND_DOWN": {},
    // "ROUND_UP": {},

    // "RANDOM": {},    // Between 0 & 1
    

    // // Sin, cos, tan. They can use table lookups for these. 
    // // "LOG": {},   // mathematical log. not logging log.

    // // First - first element of a list


    // // Ajax - get
    // // Ajax - post

    // distinct, count

    // TODO: WHERE should be part of this? Yeah, probably. No reason to treat it as a keyword. 


    // // todo: HTTP Request

    // // Group - group like values into sub lists