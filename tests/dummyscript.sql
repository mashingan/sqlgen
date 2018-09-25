CREATE TABLE users (
    username VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(20) UNIQUE NOT NULL
);

CREATE TABLE PHONES (
    `number` VARCHAR(20) UNIQUE NOT NULL,
    username VARCHAR(20) NOT NULL,
    FOREIGN KEY (username) REFERENCES users(username)
);
