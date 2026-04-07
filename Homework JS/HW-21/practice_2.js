const reverse = (str) => {
    let result = '';

    for (i = str.length - 1; i >= 0; i--){
        result = result + str[i];
    }
    return result;
}

console.log(reverse('talgat'));
console.log(reverse('abc'));   // 'cba'
console.log(reverse('JS'));    // 'SJ'
