# REQUIRE

Script require `LUA` and `LUA-SQL-MYSQL` extension.

## INSTALLATION ON UBUNTU 14
### DOWNLOAD REQUIRE PACKAGE
* `sudo apt-get install lua5.2` Install LUA5.2
* `sudo apt-get install lua-sql-mysql` Install mysql extension for LUA
* `sudo apt-get install git` Install github package

 ### SETUP
* Clone the project
  * `git clone https://github.com/AFAPARKGB/LUA_SCRIPT/`
* Move into the folder and make `setconfig` executable
  * `cd LUA_SCRIPT/`
  * `sudo chmod 777 setconfig`
  
### EXAMPLE OF USE
* Run the script
  * `sudo lua check_element.lua`
* Fill the information asked by the script <br />
  &nbsp;&nbsp;&nbsp;`MySQL Server (localhost):` Let empty for default value -> localhost <br />
  &nbsp;&nbsp;&nbsp;`MySQL User (root):` Let empty for default value -> root <br />
  &nbsp;&nbsp;&nbsp;`MySQL Password ():` Fill MySQL password <br />
  &nbsp;&nbsp;&nbsp;`MySQL Database (master2pc):` Let empty for default value -> master2pc <br />
  &nbsp;&nbsp;&nbsp;`Check Calibration (true):` Let empty for default value -> true <br />
  &nbsp;&nbsp;&nbsp;`Check communication (true):`  Let empty for default value -> true <br />
* See the folder created by the script `date_log` to check the result
