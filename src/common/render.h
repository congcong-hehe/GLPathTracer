#pragma once

#include <glad/glad.h>
#include "shader.h"

class Render
{
private:
    GLuint path_fbo_ = 0;
    GLuint temp_fbo_ = 0;
    GLuint path_texture_ = 0;
    GLuint temp_texture_ = 0;
    GLuint VAO_ = 0;
    GLuint VBO_ = 0;
    GLuint EBO_ = 0;
    unsigned int width_;
    unsigned int height_;

    Shader output_shader_;
    Shader temp_shader_;

public:
    Render(unsigned int width, unsigned int height);
    ~Render();
    void draw(Shader& shader);
};