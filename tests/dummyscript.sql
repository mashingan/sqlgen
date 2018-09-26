CREATE TABLE users (
    username VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE phones (
    `number` VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(20) NOT NULL,
    FOREIGN KEY (name) REFERENCES users(username)
);
