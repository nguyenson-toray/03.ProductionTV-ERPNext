// Polyfill for Object.hasOwn (ES2022)
if (!Object.hasOwn) {
    Object.hasOwn = function (obj, prop) {
        return Object.prototype.hasOwnProperty.call(obj, prop);
    };
}

// Additional polyfills for better compatibility
if (!Array.prototype.flat) {
    Array.prototype.flat = function (depth = 1) {
        return this.reduce(function (flat, toFlatten) {
            return flat.concat((Array.isArray(toFlatten) && depth > 0) ? toFlatten.flat(depth - 1) : toFlatten);
        }, []);
    };
}

if (!Array.prototype.flatMap) {
    Array.prototype.flatMap = function (callback, thisArg) {
        return this.map(callback, thisArg).flat();
    };
}

// Console log to confirm polyfill loaded
console.log('Polyfills loaded successfully'); 