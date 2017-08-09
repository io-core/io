//
// Copyright © 2017 Charles Perkins
//
// Permission to use, copy, modify, and/or distribute this software for any purpose with
// or without fee is hereby granted, provided that the above copyright notice and this
// permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO
// THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT
// SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR
// ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
// CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
// OR PERFORMANCE OF THIS SOFTWARE.
//

package odisp

import (
	"fmt"
        "runtime"
        "image"

        "github.com/go-gl/gl/v3.2-core/gl"
        "github.com/go-gl/glfw/v3.2/glfw"
        "github.com/go-gl/mathgl/mgl32"

)

func init() {
        // GLFW event handling must run on the main OS thread
        runtime.LockOSThread()
}

func PanicOn( err error ){
        if err != nil {
                panic(err)
        }
}



func createWindow(w,h int,b bool) *glfw.Window {

        glfw.WindowHint(glfw.ContextVersionMajor, 3)
        glfw.WindowHint(glfw.ContextVersionMinor, 2)
        glfw.WindowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile)
        glfw.WindowHint(glfw.OpenGLForwardCompatible, glfw.True)
	if b {
          glfw.WindowHint(glfw.Decorated, glfw.True)
	}else{
          glfw.WindowHint(glfw.Decorated, glfw.False)
	}
//        window, err := glfw.CreateWindow(1920, 1200, "REM", nil, nil ) //glfw.GetPrimaryMonitor(), nil)
        window, err := glfw.CreateWindow(w, h, "REM", nil, nil ) //glfw.GetPrimaryMonitor(), nil)

        PanicOn(err)

        window.MakeContextCurrent()

        err = gl.Init()
        PanicOn(err)

	nw,nh:=window.GetFramebufferSize()
	fmt.Println("Window size:",nw,nh)
	ofbw = uint32(nw)
	ofbh = uint32(nh)
	if (w < nw || h < nh ) {
	  ofd = false
	}else{
	  ofd = true
	}

	return window

}

var mptr, kcptr  *uint32
var kbptr *[16]byte
var ofbw, ofbh uint32
var ofd bool
var mbl int
var mbm int
var mbr int

var cubeVertices = []float32{
        //  X, Y, Z, U, V
        // Plane
// 16:9
        -1, -1.0, 0.0, 1.0, 0.0,
        1, -1.0, 0.0, 0.0, 0.0,
        -1, 1.0, 0.0, 1.0, 1.0,
        1, -1.0, 0.0, 0.0, 0.0,
        1, 1.0, 0.0, 0.0, 1.0,
        -1, 1.0, 0.0, 1.0, 1.0,
// 2:1
//        -2, -1.0, 0.0, 1.0, 0.0,
//        2, -1.0, 0.0, 0.0, 0.0,
//        -2, 1.0, 0.0, 1.0, 1.0,
//        2, -1.0, 0.0, 0.0, 0.0,
//        2, 1.0, 0.0, 0.0, 1.0,
//        -2, 1.0, 0.0, 1.0, 1.0,
}

func cpos(w *glfw.Window, xpos float64, ypos float64) {
        
        mx := int32(int16(xpos))
        my := int32(int16(ofbh-uint32(ypos)))  //768

        *mptr = uint32(mbr)<<24|uint32(mbm)<<25|uint32(mbl)<<26| (uint32(my)<<12 & 0x00FFF000) | (uint32(mx) & 0x00000FFF)
}


func cbtn(w *glfw.Window, button glfw.MouseButton, action glfw.Action, mod glfw.ModifierKey) {
        pos:= *mptr & 0x00FFFFFF

	switch button {
	case glfw.MouseButton1 :
		if action==glfw.Press {
			mbl=1
		}else{
			mbl=0
		}
        case glfw.MouseButton2 :
                if action==glfw.Press {
                        mbr=1
                }else{
                        mbr=0
                }
        case glfw.MouseButton3 :
                if action==glfw.Press {
                        mbm=1
                }else{
                        mbm=0
                }
        
	}
        *mptr = uint32(mbr)<<24 | uint32(mbm)<<25 | uint32(mbl)<<26 | pos
}

func kbtn(w *glfw.Window, key glfw.Key, scancode int, action glfw.Action, mods glfw.ModifierKey) {
		     var scx bool
		     var sc byte
	             kc := []byte      {   0,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x76,
                                        0x16,0x1e,0x26,0x25,0x2e,0x36,0x3d,0x3e,0x46,0x45,
                                        0x4e,0x55,0x66,0x00,0x15,0x1d,0x24,0x2d,0x2c,0x35,
                                        0x3c,0x43,0x44,0x4d,0x54,0x5b,0x5a,0x00,0x1c,0x1b,
                                        0x23,0x2b,0x34,0x33,0x3b,0x42,0x4b,0x4c,0x52,0x0e,
                                        0x12,0x5d,0x1a,0x22,0x21,0x2a,0x32,0x31,0x3a,0x41,
                                        0x49,0x4a,0x59,   0,   0,0x29,   0,   0,   0,   0,
                                        70,71,72,73,74,75,76,77,78,79,
                                        80,81,82,83,84,85,86,87,88,89 }


		       	   switch action {
			   case glfw.Press:
			   	k:= scancode
				if k > 223 { k = (k - 224) + 60 }
			   	if k < 93 {
				  scx = false
				  sc =  kc[k] 
			   	}
			   case glfw.Release:
			   	k:= scancode
				if k > 223 { k = (k - 224) + 60 }
			   	if k < 93 { 
			   	  scx = true //kChan <- kmsg{ 0xF0 }
				  sc =  kc[k] 
				}

			}


//    if (action == glfw.Press){
//        fmt.Println("Pressed",key,"scancode",scancode,"pcscan",sc,"extended",scx)
//    }
//    if (action == glfw.Release){
//        fmt.Println("Release",key,"scancode",scancode,"pcscan",sc,"extended",scx)
//    }
     if sc != 0 {
	if scx {
            kbptr[*kcptr]=0xF0
            *kcptr++
	}
            kbptr[*kcptr]=sc
            *kcptr++
     }
}

func Initfb( vChan chan [2]uint32, mouse *uint32, key_buf *[16]byte, key_cnt, fbw, fbh *uint32, verbose bool, readyChan chan [2]uint32 ) {

     //   *fbw=1536 // 1600 max thinkpad
     //   *fbh=768  // 900 max thinkpad
     //   *fbw=1920 //1600 
     //   *fbh=1200 //838

	mptr = mouse
	kbptr = key_buf
	kcptr = key_cnt
     //   fbwptr = fbw       
//	fbhptr = fbh

        err := glfw.Init()
	PanicOn( err )        
        defer glfw.Terminate()

	window := createWindow(1920,1200,false)
	*fbw = ofbw
	*fbh = ofbh
	readyChan <- [2]uint32{ofbw,ofbh}
	window.Destroy()
        window = createWindow(int(ofbw),int(ofbh),false)


        glprog := makeprog()
        gl.UseProgram(glprog)

        projection := mgl32.Perspective(mgl32.DegToRad(45), 1, 0.1, 10.0)     //DegToRad(45.0)  ... 0.1, 10.0)
        projectionUniform := gl.GetUniformLocation(glprog, gl.Str("projection\x00"))
        gl.UniformMatrix4fv(projectionUniform, 1, false, &projection[0])

	//-2.415 for 2:1, -2.615 for 16:9
        camera := mgl32.LookAtV(mgl32.Vec3{0, 0, -2.415}, mgl32.Vec3{0, 0, 0}, mgl32.Vec3{0, 1, 0})   // eye, center, up
        cameraUniform := gl.GetUniformLocation(glprog, gl.Str("camera\x00"))
        gl.UniformMatrix4fv(cameraUniform, 1, false, &camera[0])

        model := mgl32.Ident4()
        modelUniform := gl.GetUniformLocation(glprog, gl.Str("model\x00"))
        gl.UniformMatrix4fv(modelUniform, 1, false, &model[0])

        textureUniform := gl.GetUniformLocation(glprog, gl.Str("tex\x00"))
        gl.Uniform1i(textureUniform, 0)

        gl.BindFragDataLocation(glprog, 0, gl.Str("outputColor\x00"))

        var fb *image.RGBA = image.NewRGBA(image.Rect(0,0,int(*fbw),int(*fbh)))
        texture := blankT(fb)
        
        

        // Configure the vertex data
        var vao uint32
        gl.GenVertexArrays(1, &vao)
        gl.BindVertexArray(vao)

        var vbo uint32
        gl.GenBuffers(1, &vbo)
        gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
        gl.BufferData(gl.ARRAY_BUFFER, len(cubeVertices)*4, gl.Ptr(cubeVertices), gl.STATIC_DRAW)

        vertAttrib := uint32(gl.GetAttribLocation(glprog, gl.Str("vert\x00")))
        gl.EnableVertexAttribArray(vertAttrib)
        gl.VertexAttribPointer(vertAttrib, 3, gl.FLOAT, false, 5*4, gl.PtrOffset(0))

        texCoordAttrib := uint32(gl.GetAttribLocation(glprog, gl.Str("vertTexCoord\x00")))
        gl.EnableVertexAttribArray(texCoordAttrib)
        gl.VertexAttribPointer(texCoordAttrib, 2, gl.FLOAT, false, 5*4, gl.PtrOffset(3*4))

        // Configure global settings
        gl.Enable(gl.DEPTH_TEST)
        gl.DepthFunc(gl.LESS)
        gl.ClearColor(1.0, 1.0, 1.0, 1.0)

        fmt.Println("Launching Graphics Update Handler")
        go func() {
          for {
                v := <- vChan
		if verbose { fmt.Println("video msg:",v)}
                address:=v[0]
                value:=v[1]
                for pi:=0;pi<32;pi++{
                        pxcr:=uint8(238)
                        pxcg:=uint8(223)
                        pxcb:=uint8(204)
                        if value & (1 << uint32(pi) ) != 0 {
                            pxcr = uint8(0)
                            pxcg = uint8(0)
                            pxcb = uint8(0)
                        }

                        fbo:=((address)-(0x000E7F00))/4
                        fby:=fbo/(*fbw/32)
                        fbx:=((fbo*32)%*fbw)+uint32(pi)
                        if int(fby) < int(*fbh) && int(fbx) < int(*fbw) {
                           fb.Pix[0+ ((fby)*(*fbw)+fbx)*4]=pxcr
                           fb.Pix[1+ ((fby)*(*fbw)+fbx)*4]=pxcg
                           fb.Pix[2+ ((fby)*(*fbw)+fbx)*4]=pxcb
                           fb.Pix[3+ ((fby)*(*fbw)+fbx)*4]=255

                        }
                }
          }
        }()

        window.SetInputMode(glfw.CursorMode,glfw.CursorHidden)
	window.SetCursorPosCallback(cpos)
        window.SetMouseButtonCallback(cbtn)
        window.SetKeyCallback(kbtn)

        for !window.ShouldClose() {
                gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
                gl.UseProgram(glprog)
                gl.UniformMatrix4fv(modelUniform, 1, false, &model[0])
                gl.BindVertexArray(vao)
                gl.ActiveTexture(gl.TEXTURE0)
		
		gl.TexImage2D(
			gl.TEXTURE_2D,
                	0,
                	gl.RGBA,
                	int32(fb.Rect.Size().X),
                	int32(fb.Rect.Size().Y),
                	0,
                	gl.RGBA,
                	gl.UNSIGNED_BYTE,
                	gl.Ptr(fb.Pix))


		gl.BindTexture(gl.TEXTURE_2D, texture)
                gl.DrawArrays(gl.TRIANGLES, 0, 6*2*3)

                window.SwapBuffers()
                glfw.PollEvents()
        }
}

func makeprog() uint32 {

        v := compile( `#version 330
	uniform mat4 projection;
	uniform mat4 camera;
	uniform mat4 model;

	in vec3 vert;
	in vec2 vertTexCoord;

	out vec2 fragTexCoord;

	void main() {
	    fragTexCoord = vertTexCoord;
	    gl_Position = projection * camera * model * vec4(vert, 1);
	}
	` + "\x00"  , gl.VERTEX_SHADER)


        f := compile(`#version 330
	uniform sampler2D tex;
	in vec2 fragTexCoord;
	out vec4 outputColor;

	void main() {
	    outputColor = texture(tex, fragTexCoord);
	}   
	` + "\x00", gl.FRAGMENT_SHADER)
        
        p := gl.CreateProgram()

        gl.AttachShader(p, v)
        gl.AttachShader(p, f)
        gl.LinkProgram(p)

        var status int32
        gl.GetProgramiv(p, gl.LINK_STATUS, &status)
        if status == gl.FALSE {
                PanicOn( fmt.Errorf("failed to link opengl"))
        }

        gl.DeleteShader(v)
        gl.DeleteShader(f)
        return p
}

func compile(source string, shaderType uint32) uint32 {

        shader := gl.CreateShader(shaderType)

        csources, free := gl.Strs(source)
        gl.ShaderSource(shader, 1, csources, nil)
        free()
        gl.CompileShader(shader)

        var status int32
        gl.GetShaderiv(shader, gl.COMPILE_STATUS, &status)
        if status == gl.FALSE {
                PanicOn(fmt.Errorf("failed to compile opengl"))
        }

        return shader
}

func blankT(b *image.RGBA) uint32 {

        var t uint32
        gl.GenTextures(1, &t)
        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, t)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
        gl.TexImage2D(
                gl.TEXTURE_2D,
                0,
                gl.RGBA,
                int32(b.Rect.Size().X),
                int32(b.Rect.Size().Y),
                0,
                gl.RGBA,
                gl.UNSIGNED_BYTE,
                gl.Ptr(b.Pix))

        return t
}


                                                                                                         

