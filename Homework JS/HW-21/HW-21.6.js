
const ariphmeticsNumber = (arr) => {
    let sum = 0;

    for (let i = 0; i < arr.length; i++) {
        sum = sum + arr[i];
    }
    return sum / arr.length;
};
const southData = [13, 15, 19, 26, 21, 22, 23]; 
const westData = [15, 14, 16, 18, 17, 24, 25]; 
const eastData = [20, 17, 19, 15, 24, 25, 26]; 
const northData = [19, 18, 23, 20, 23, 19, 31]; 

console.log(getAverage(southData)); // ???
console.log(getAverage(westData));  // ???
console.log(getAverage(eastData));  // ???
console.log(getAverage(northData)); // ???