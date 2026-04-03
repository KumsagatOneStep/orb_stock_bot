const multiply = (a, b) => {
    if (a === undefined || b === undefined) {
        return "Error: two settings need";
    }
    let result = 0;
    for (let i = 0; i < b; i++) {
        result = result + a;
    }
    
    return result;
};

console.log(multiply(2,5));

    