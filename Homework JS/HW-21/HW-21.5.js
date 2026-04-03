const countChars = (char, str) => {
    let  count = 0;

    for (i = 0; i < str.length; i++) {
        if (str[i] === char) {
            count++;
        }
    }
    return count;
}
console.log(countChars('b', 'bbbbb'));
console.log(countChars('s', 'mississippi'));