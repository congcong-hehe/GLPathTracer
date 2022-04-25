#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <string>
#include "common/shader.h"
#include "common/render.h"
#include "config.h"

using namespace std;

void processInput(GLFWwindow *window);

int main()
{
    glfwInit();
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "GLPathTracer", NULL, NULL);
    if (window == NULL)
    {
        std::cout << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwSetWindowSizeLimits(window, 800, 600, 800, 600);    // 固定窗口大小
    glfwMakeContextCurrent(window);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    Shader path_shader(project_path + "src/shader/vs.glsl", project_path + "src/shader/base_fs.glsl");
    glm::vec3 origin(0.0f, 0.0f, 0.0f);
    glm::vec3 horizontal(4.0f, 0.0f, 0.0f);
    glm::vec3 vertical(0.0f, 3.0f, 0.0f);
    float focal_length = 1.0;   // 摄像机到远平面的距离

    path_shader.bind();
    path_shader.setVec3("camera.ori", origin);
    path_shader.setVec3("camera.horizontal", horizontal);
    path_shader.setVec3("camera.vertical", vertical);
    path_shader.setVec3("camera.lower_left_corner", origin - horizontal / 2.0f - vertical / 2.0f - glm::vec3(0.0f, 0.0f, focal_length));

    path_shader.setVec3("spheres[0].center", 0.0f, 0.0f, -1.0f);
    path_shader.setFloat("spheres[0].radius", 0.6f);
    path_shader.setVec3("spheres[1].center", 0.0f, -100.5f, -1.0f);
    path_shader.setFloat("spheres[1].radius", 100.0f);

    path_shader.setVec3("tri.p0", 0.0f, 0.5f, -1.0f);
    path_shader.setVec3("tri.p1", -0.5f, -0.5f, -1.0f);
    path_shader.setVec3("tri.p2", 0.5f, -0.5f, -1.0f);
    path_shader.setVec3("tri.n0", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tri.n1", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tri.n2", 0.0f, 0.0f, 1.0f);

    Render render(SCR_WIDTH, SCR_HEIGHT);

    unsigned int frame_count = 0;
    while (!glfwWindowShouldClose(window))
    {
        frame_count ++;
        processInput(window);

        glClearColor(1.f, 1.0f, 1.f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        path_shader.bind();
        path_shader.setUInt("frame_count", frame_count);
        render.draw(path_shader);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glfwTerminate();
    return 0;

}

void processInput(GLFWwindow *window)
{
    if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);
}
