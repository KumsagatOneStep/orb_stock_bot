const sumEven = (arr) => {
    let sum = 0;

    for (let i = 0; i < arr.length; i++) {
        if (typeof arr[i] !== 'number') continue;
        if (arr[i] % 2 !== 0) continue;
        sum = sum + arr[i];
    }

    return sum;
};

const numbers = [1, 2, 5, 10, 15, 25, 32, 'jack' , 64];
console.log(sumEven(numbers));