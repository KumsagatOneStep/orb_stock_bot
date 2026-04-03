const power = (a, b = 2) => {
    if (a === undefined) {
        return "Error";
    }

    let result = 1;

    for (i = 0; i < b; i++) {
        result = result * a;
    }
    return result;
};

const a = parseInt(prompt("Enter the number: "));
const b = parseInt(prompt("Enter the power: "));

console.log(power(a, isNaN(b) ? undefined : b));