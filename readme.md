treeForge
Read from a txt tree diagram and create the subfolders and files in an empty directory.
Read the prompt.md for more detail.

**Installation**
chmod +x treeForge
sudo ln -s <dir>/treeForge /usr/local/bin/treeForge

**Usage**

***treeForge***
1. Generate a tree.txt 
- With tools like file-tree-generator with vscode
- or using the generate_tree.py in this project to generate a json version of the project directory structure
2. Generate the files and subfolders with treeForge
(Use `treeForge -h` for usage detail)

***generate_tree.py***
A py script that will generate a json format project directory structure, for passing into LLM for quick understanding of the project.