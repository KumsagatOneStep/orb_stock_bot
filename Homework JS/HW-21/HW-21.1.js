

const convertToFatrenheit = (celsius) => {
    return (celsius * 9/5 ) + 32;
};

const celsius = parseFloat(prompt('Enter temperature is Celsius'));
const fahrenheit = convertToFatrenheit(celsius);

console.log(fahrenheit);
alert(fahrenheit);
