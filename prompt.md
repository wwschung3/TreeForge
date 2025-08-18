# ✅ Prompt for AI‑Coding Agent – Directory‑Tree Builder

**Goal**  
Write a command‑line utility that reads a *directory‑tree diagram* (txt format) and **creates** the corresponding directories and files under a given root directory.  
The tool must respect an optional `.gitignore` file and must **skip** creation of items that already exist.

---

**Language**
- bash

## 1. Problem Statement

You must implement the following functionality:

1. **Input**  
   - `root_dir_path` – filesystem path where the tree will be materialised.  
   - `tree_file_path` – path to a txt file that describes the tree.  
   - `level` - integer; optional; default null; how many level from the root directory that the file tree should be followed
   - `use_gitignore` – boolean flag; optional; default false; if true, the tool must look for a `.gitignore` file in `root_dir_path` and honour its rules.


2. **Tree Diagram Format Sample(TXT)**
root_dir
 ┣ dir1
 ┃ ┣ subdir
 ┃ ┃ ┣ file4.js
 ┃ ┣ file3.txt
 ┣ dir2
 ┣ file1.md
 ┣ file2.json

 3. **Usage example:**
 sample input:
 `create_tree /my_dir ./tree_diagram.txt 2`

 sample output:
The files below should be generate (file4 is not generated because it is in level 3 while the command request to generate the file up to level 2 only)
 my_dir
 ┣ dir1
 ┃ ┣ subdir
 ┃ ┣ file3.py
 ┣ dir2
 ┣ file1.py
 ┣ file2.json