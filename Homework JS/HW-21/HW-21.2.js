
const validator = () => {
    const input = prompt('Enter a number:');

    if(input === null) {
        return 'We button cancel';
    }
    const number = parseInt(input);

    if (Number.isNaN(number)){
        return 'We input not number';
    }
    if (number > 0) {
        return 'Вы ввели положительное число';
    } else if (number < 0) {
        return 'Вы ввели отриуательное число';
    } else {
        return 'Вы ввели 0';
    }
};

const result = validator();
console.log(result);