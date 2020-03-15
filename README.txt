Pluggable Helpers Mod v1.0
By Leslie E. Krause

Pluggable Helpers provides an API to fully automatate the process of downloading and 
installing Lua helper methods, classes, and libraries within Minetest.

Modularity is extremely important when it comes to maintaining large scale code-bases 
such as games and mods in Minetest. Helper classes and methods and even libraries serve 
this purpose. But so often they are re-implemented over-and-over again since nobody wants 
to rely on external dependencies in their mods and games. Eventually some helpers may be 
integrated into the engine, but even that is often a lengthy review process.

This is where Pluggable Helpers comes into the picture.

   "The core philosophy of Pluggable Helpers is to empower the community to create an 
   evolving game-development API through the use of a jointly maintained repository of 
   helper classes, methods, and libraries that can be downloaded and installed on-the-fly 
   with no intervention required by the end-user."

Although Pluggable Helpers has no dependencies in and of itself, it does need perform HTTP 
requests. Therefore it must be added to the list of "secure_http_mods" in minetest.conf.


Repository
----------------------

Browse source code...
  https://bitbucket.org/sorcerykid/plugins

Download archive...
  https://bitbucket.org/sorcerykid/plugins/get/master.zip
  https://bitbucket.org/sorcerykid/plugins/get/master.tar.gz

Installation
----------------------

  1) Unzip the archive into the mods directory of your game
  2) Rename the plugins-master directory to "plugins"
  3) Add "plugins" as a dependency to any mods using the API

License of source code
----------------------------------------------------------

The MIT License (MIT)

Copyright (c) 2020, Leslie Krause (leslie@searstower.org)

Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the "Software"), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

For more details:
https://opensource.org/licenses/MIT
