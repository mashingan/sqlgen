CREATE TABLE users (
    username VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(20) UNIQUE NOT NULL,
    address VARCHAR(20) UNIQUE INDEX NOT NULL
);

CREATE TABLE phones (
    `number` VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(20) NOT NULL,
    FOREIGN KEY (name) REFERENCES users ( username)
);

CREATE TABLE address(
    label VARCHAR(20) UNIQUE INDEX NOT NULL REFERENCES users(address),
    region VARCHAR(20) NOT NULL
);
