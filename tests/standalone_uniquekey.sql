CREATE TABLE users (
    username VARCHAR(20) NOT NULL,
    email VARCHAR(20) NOT NULL,
    address VARCHAR(20) UNIQUE INDEX NOT NULL,
    CONSTRAINT users_username UNIQUE(username),
    CONSTRAINT users_email UNIQUE (email)
);
