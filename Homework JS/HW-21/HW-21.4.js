const power = (a, b = 2) => {
    if (a === undefined) {
        return "Error";

    }
        let result = 1;

        for (let i = 0; i < b; i++){
            result = result * a;
        }
        return result;
};

const a = parseInt(prompt('Input the number:'));
const b = parseInt(prompt('Input the power:'));

console.log(power(a, b));
