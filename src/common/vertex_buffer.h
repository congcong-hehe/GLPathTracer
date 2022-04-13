#pragma once

#include <glad/glad.h>

class VertexBuffer
{
private:
    unsigned int VBO = 0, VAO = 0, EBO = 0;

public:
    VertexBuffer::VertexBuffer(const float * vertices, const unsigned int *indices, unsigned int vertices_size, unsigned int indices_size);

    void bind()
    {
        glBindVertexArray(VAO); 
    }

    void unbind()
    {
        glBindVertexArray(0); 
    }
};