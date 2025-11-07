### [Under Construction]


HotWire Nine [LiCap Framework] is a lighting model inspired by MatCap tech, but in light space rather than screen space.

[![HOTWIRE NINE IN ACTION](https://img.youtube.com/vi/Pm0aBmibGiE/0.jpg)](https://www.youtube.com/shorts/Pm0aBmibGiE)


## Usage:
- Locate the "Test.tscn" file [in the root directory] and load it [to get the preview in the video].
- Locate the "LiCap.gdshader" file [in the root directory] and double click it to inspect the shader code.
- Locate the LiCapLight in the hirarchy window, move it around to test light interaction and compare.


### Warning [creating new materials]
because of abstraction limitations, the LiCap shader **Cannot** use the default lights in Godot.
- To **use the light with the new materials**: locate the "LiCapLight" from the hirarchy, you will find the parameters of its custom script, you need to **drag your new material to the list**, so the light can update its location
