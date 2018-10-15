CREATE TABLE users (
    username CHARACTER VARYING(20) UNIQUE NOT NULL,
    email CHARACTER VARYING(20) UNIQUE NOT NULL,
    address VARCHAR(20) UNIQUE INDEX NOT NULL
);

CREATE TABLE phones (
    `number` VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(20) NOT NULL,
    
    --FOREIGN KEY (name) REFERENCES users ( username)
    --    ON UPDATE CASCADE ON DELETE CASCADE

    CONSTRAINT "users_tables_name_username_fk" FOREIGN KEY (name) REFERENCES
        users ( username ) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE address(
    label VARCHAR(20) UNIQUE INDEX NOT NULL REFERENCES users(address),
    region VARCHAR(20) NOT NULL
);
