#!/usr/bin/env python
# coding: utf-8

import os
import yaml
import sqlite3

"""
yaml_file: the name of input YAML file.
db_file: the name of output sqlite3 file.
schema_file: the name of file with database schema.
"""

yaml_file = "style-guide.yaml"
schema_file = "db_schema.sql"
db_file = "writing_style.db"
opened_yaml = None
opened_db = None


"""
    Load YAML file and transform it into python representation.
"""
def load_yaml():
    # Print message.
    print("\tLoading yaml file.")
    # Set global variable.
    global opened_yaml

    # Try to open the yaml file.
    try:
        opened_yaml = file(yaml_file, 'r')
    except IOError, e:
        print e

    return yaml.load(opened_yaml)


"""
    Creates new, empty database file and run command for fetch database schema in it.
"""
def load_db():
    # Print message.
    print("\tCreating db file.")

    # Set variable as global.
    global opened_db
    global schema_file

    # Remove old database.
    if os.path.exists(db_file):
        os.remove(db_file)


    # Open database file.
    with sqlite3.connect(db_file) as opened_db:
        print("\t\tCreating database schema.")
        # Fetch database schema and apply it.
        with open(schema_file, 'rt') as schema_desc:
            schema = schema_desc.read()

        # Apply the schema.
        opened_db.executescript(schema)


"""
    Add information about one word into database.
"""
def add_this_item_into_db(one_item):
    # Remove automatic substituting yes and no words by boolean values
    if one_item["use_it"] == "avoid":
        one_item["use_it"] = "avoid"
    elif one_item["use_it"]:
        one_item["use_it"] = "yes"
    elif one_item["use_it"] == None:
        one_item["use_it"] = None
    else:
        one_item["use_it"] = "no"

    global opened_db

    # Create cursor for inserting data to the database.
    curs = opened_db.cursor()

    # Use insert query to insert information about one item.
    curs.execute("INSERT INTO item(name, class, desc, use_it, type) VALUES(:name, :class, :desc, :use_it, :type)", one_item)

    # Commit database changes.
    opened_db.commit()

    return curs.lastrowid


"""
    Find ids of all items which name = 'item'.
"""
def find_item_ids(item):
    global opened_db

    # Create cursor for finding data to the database.
    curs = opened_db.cursor()

    # Use insert query to insert information about one item.
    curs.execute("SELECT id FROM item WHERE name=?", (item,))

    return curs.fetchall()


"""
    Add new row in reference table.
"""
def add_reference_row(item, refer_to):
    global opened_db

    # Create cursor for inserting data to the database.
    curs = opened_db.cursor()

    for one_id in refer_to:
        # Use insert query to insert information about one item.
        curs.execute("INSERT INTO reference(id_current, id_refer) VALUES(?, ?)", (item, one_id[0]))

    # Commit database changes.
    opened_db.commit()


"""
    Find name of item by id.
"""
def find_name(item_id):
    global opened_db

    # Create cursor for inserting data to the database.
    curs = opened_db.cursor()

    # Execute SELECT query.
    curs.execute("SELECT name FROM item WHERE id=?", (item_id,))

    # Return value.
    return curs.fetchone()[0]


"""
    Add item to the reference table.
"""
def add_references_to_other_item(references):
    # Go through all items in reference table.
    for item_id, items in references.iteritems():
        # Go through all items which are refered by current item.
        for ref_item in items:
            # Get id of refered item.
            refer_to_item_id = find_item_ids(ref_item)

            # Print message.
            print("\t\tAdding reference from '" + find_name(item_id) + "' to '" + ref_item + "'.")

            # Add reference.
            add_reference_row(item_id, refer_to_item_id)



"""
    Parse data from lists and add them into database.
"""
def insert_data_into_db(list_id_dicts):
    # Print message.
    print("\tInserting data into database.")

    # Set variables.
    global opened_db
    counter_item = 0
    counter_ref = 0
    references = {}

    # Go through all items from YAML file
    for one_item in list_id_dicts:
        # Count these items.
        counter_item += 1

        # Get key and value.
        for key, value in one_item.iteritems():

            refers_to_this_item = value["refers"]
            # Remove refers from attributes of current word.
            del value["refers"]

            # Add current word into its attributes -> easier inserting into database.
            value["name"] = key

            # Print the word which is currently added.
            print("\t\tInserting '" + key + "'.")

            # Add this word with its attributes into database.
            test = add_this_item_into_db(value)

            # Add refers into reference table (will be processed later.)
            if len(refers_to_this_item) > 0:
                references[test] = refers_to_this_item
                counter_ref += 1

    # Print information line.
    print("\tAdding references between words.")

    # Fill reference table.
    add_references_to_other_item(references)

    # Return number of added items.
    return {"items": counter_item, "refers": counter_ref}


"""
    Prints summary (number of added items).
"""
def print_summary(summary):
    print("\tPrinting summary:")
    print("\t\t" + str(summary["items"]) + " items added.")
    print("\t\t" + str(summary["refers"]) + " references added.")


"""
    Function which closes all descriptors.
"""
def close_all():
    print("\tClosing opened files.")
    opened_db.close()
    opened_yaml.close()


"""
    Main funciton.
"""
def main():
    # Load yaml file
    list_of_dicts = load_yaml()

    # Create new db file.
    load_db()

    #insert all data into database
    summary = insert_data_into_db(list_of_dicts)

    # create summary with informations about conversion.
    print_summary(summary)

    # Close file descriptors.
    close_all()


if __name__ == "__main__":
    main()
