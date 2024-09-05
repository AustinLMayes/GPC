# GPCUtils

An extremely niche utility library for converting plans from Planning Center Services to a master control Obsidian Onyx cuelist.

General order of operations:
1. rake load_show - Loads the show file into the database.
2. rake create_service[id] - Downloads the plan from Planning Center Services and creates a `service.json` file that can be manipulated.
3. rake import_service - Imports the `service.json` file into the database.
4. rake save_show - Creates a massive SQL export of the show file that can be imported into the Onyx database.

**Note:** This is a work in progress and will need modifications to work with your specific use case. Use this as a starting point and modify as needed. I may make this more generic in the future, but for now it is very specific to my needs.
