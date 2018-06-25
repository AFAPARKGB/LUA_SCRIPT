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
  * `sudo lua check_element.lua`<br />
     `MySQL Server (localhost):`<br />
     `MySQL User (root):`<br />
     `MySQL Password ():`<br />
     `MySQL Database (master2pc):`<br />
     `Check Calibration (true):`<br />
     `Check communication (true):`<br />
