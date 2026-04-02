const user1 = { firstName: 'Ivan', lastName: 'Petrov', username: 'ivan' };
const user2 = { username: 'ivan' };
const user3 = {};

const getUserDisplayName = (user) => {
  if (!user) {
      return 'Anonymous';
  }

  if (user.firstName && user.lastName) {
      return user.firstName + ' ' + user.lastName;
  }

  if (user.username) {
      return '@' + user.username;
  }

  return 'Anonymous';
}

console.log(getUserDisplayName(user1));
console.log(getUserDisplayName(user2));
console.log(getUserDisplayName(user3));
console.log(getUserDisplayName(null));