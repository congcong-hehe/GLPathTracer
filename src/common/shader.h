#pragma once

#include <string>
#include <glm/glm.hpp>
#include <glad/glad.h>

class Shader
{
public:
    Shader();
    Shader(const std::string &vertexPath, const std::string& fragmentPath);
    void init(const std::string &vertexPath, const std::string& fragmentPath);
    inline void bind();
    inline void unbind();
    inline void setBool(const std::string& name, bool value) const;
    inline void setInt(const std::string& name, int value) const;
    inline void setUInt(const std::string& name, int value) const;
    inline void setFloat(const std::string& name, float value) const;
    inline void setMat4(const std::string& name, const glm::mat4& mat) const;
    inline void setVec3(const std::string& name, const glm::vec3& value) const;
    inline void setVec3(const std::string& name, float x, float y, float z) const;

private:
    unsigned int ID = 0;
    void checkCompileErrors(unsigned int shader, std::string type);
};

// activate the shader
void Shader::bind()
{
    glUseProgram(ID);
}

void Shader::unbind()
{
    glUseProgram(0);
}

void Shader::setBool(const std::string& name, bool value) const
{
    glUniform1i(glGetUniformLocation(ID, name.c_str()), (int)value);
}

void Shader::setInt(const std::string& name, int value) const
{
    glUniform1i(glGetUniformLocation(ID, name.c_str()), value);
}

void Shader::setUInt(const std::string& name, int value) const
{
    glUniform1ui(glGetUniformLocation(ID, name.c_str()), value);
}

void Shader::setFloat(const std::string& name, float value) const
{
    glUniform1f(glGetUniformLocation(ID, name.c_str()), value);
}

void Shader::setMat4(const std::string& name, const glm::mat4& mat) const
{
    glUniformMatrix4fv(glGetUniformLocation(ID, name.c_str()), 1, GL_FALSE, &mat[0][0]);
}

void Shader::setVec3(const std::string& name, const glm::vec3& value) const
{
    glUniform3fv(glGetUniformLocation(ID, name.c_str()), 1, &value[0]);
}

void Shader::setVec3(const std::string& name, float x, float y, float z) const
{
    glUniform3f(glGetUniformLocation(ID, name.c_str()), x, y, z);
}