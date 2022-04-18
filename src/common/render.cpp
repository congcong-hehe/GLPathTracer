#include "render.h"
#include "../config.h"

Render::Render(unsigned int width, unsigned int height) : width_(width), height_(height)
{
    // 配置vao
    float vertices[] = {
         1.0f,  1.f, 0.0f,  1.0f, 1.0f, // top right
         1.0f, -1.0f, 0.0f,  1.0f, 0.0f,// bottom right
        -1.0f, -1.0f, 0.0f,  0.0f, 0.0f, // bottom left
        -1.0f,  1.0f, 0.0f,  0.0f, 1.0f   // top left 
    };
    unsigned int indices[] = {  // note that we start from 0!
        0, 1, 3,  // first Triangle
        1, 2, 3   // second Triangle
    };

    glGenVertexArrays(1, &VAO_);
    glGenBuffers(1, &VBO_);
    glGenBuffers(1, &EBO_);
    glBindVertexArray(VAO_);

    glBindBuffer(GL_ARRAY_BUFFER, VBO_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));

    glBindBuffer(GL_ARRAY_BUFFER, 0); 

    // 配置fbo
    glGenFramebuffers(1, &path_fbo_);
    glGenFramebuffers(1, &temp_fbo_);

    glBindFramebuffer(GL_FRAMEBUFFER, path_fbo_);
    glGenTextures(1, &path_texture_);
    glBindTexture(GL_TEXTURE_2D, path_texture_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, path_texture_, 0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, temp_fbo_);
    glGenTextures(1, &temp_texture_);
    glBindTexture(GL_TEXTURE_2D, temp_texture_);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glBindTexture(GL_TEXTURE_2D, 0);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, temp_texture_, 0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

    output_shader_.init("../../../../src/shader/vs.glsl", "../../../../src/shader/output_fs.glsl");
}

Render::~Render()
{
    glDeleteFramebuffers(1, &path_fbo_);
    glDeleteFramebuffers(1, &temp_fbo_);
}

void Render::draw(Shader& shader)
{
    glBindFramebuffer(GL_FRAMEBUFFER, path_fbo_);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) // 检测帧缓冲是否完整
    {
        glBindTexture(GL_TEXTURE_2D, temp_texture_);
        shader.bind();
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, temp_fbo_);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) // 检测帧缓冲是否完整
    {
        glBindTexture(GL_TEXTURE_2D, path_texture_);
        output_shader_.bind();
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    }

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) // 检测帧缓冲是否完整
    {
        glBindTexture(GL_TEXTURE_2D, path_texture_);
        output_shader_.bind();
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    }
}