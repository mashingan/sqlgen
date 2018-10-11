CREATE TABLE users (
    username VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(20) UNIQUE NOT NULL,
    address VARCHAR(20) UNIQUE INDEX NOT NULL,
    created_at timestamp with time zone
);

CREATE TABLE phones (
    `number` VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(20) NOT NULL,
    buyday timestamp without time zone,
    
    --FOREIGN KEY (name) REFERENCES users ( username)
    --    ON UPDATE CASCADE ON DELETE CASCADE

    CONSTRAINT "users_tables_name_username_fk" FOREIGN KEY (name) REFERENCES
        users ( username ) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE address(
    label VARCHAR(20) UNIQUE INDEX NOT NULL REFERENCES users(address),
    region VARCHAR(20) NOT NULL
);
