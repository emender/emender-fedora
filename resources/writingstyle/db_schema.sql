-- Schema for writing style database.

-- items
create table item (
    id          integer primary key autoincrement not null,
    name        text,
    class       text,
    desc        text,
    use_it      boolean,
    type        text
);

-- references between items
create table reference (
    id_current integer references item(id) not null,
    id_refer   integer references item(id) not null,
    primary key(id_current, id_refer)
);