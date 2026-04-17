const findSum = (obj) => {
    let sum = 0;

    for (const key in obj) {
        if (typeof obj[key] === 'number') {
            sum = sum + obj[key];
        }
    }
    return sum;
};

const salaries = {
    'Vasiliy': 100,
    'Piotr': 300,
    'Daria': 250,
    'isPaid': false
};

console.log(findSum(salaries));