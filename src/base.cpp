#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <string>
#include "common/shader.h"
#include "common/render.h"
#include "config.h"
#include <time.h>
#include <windows.h>

using namespace std;

// 选择使用N卡，笔记本默认使用独显
extern "C" 
{
__declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
}

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
    glfwSetWindowSizeLimits(window, 600, 600, 600, 600);    // 固定窗口大小
    glfwMakeContextCurrent(window);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress))
    {
        std::cout << "Failed to initialize GLAD" << std::endl;
        return -1;
    }

    Shader path_shader(project_path + "src/shader/vs.glsl", project_path + "src/shader/base_fs.glsl");
    glm::vec3 origin(0.0f, 0.0f, 10.0f);
    glm::vec3 horizontal(4.0f, 0.0f, 0.0f);
    glm::vec3 vertical(0.0f, 4.0f, 0.0f);
    float focal_length = 6.0;   // 摄像机到远平面的距离

    path_shader.bind();
    path_shader.setVec3("camera.ori", origin);
    path_shader.setVec3("camera.horizontal", horizontal);
    path_shader.setVec3("camera.vertical", vertical);
    path_shader.setVec3("camera.lower_left_corner", origin - horizontal / 2.0f - vertical / 2.0f - glm::vec3(0.0f, 0.0f, focal_length));

    path_shader.setVec3("materials[0].color", 1.0f, 1.0f, 1.0f);    // 白色漫反射
    path_shader.setFloat("material[0].specularRate", 0.0f);
    path_shader.setFloat("material[0].refraceRate", 0.0f);
    
    path_shader.setVec3("materials[1].color", 50.0f, 50.0f, 50.0f);    // 光源
    path_shader.setBool("materials[1].isEmissive", true);

    path_shader.setVec3("materials[2].color", 1.0f, 0.5f, 0.5f);    // 红色

    path_shader.setVec3("materials[3].color", 0.5f, 1.0f, 1.0f);    // 蓝色

    path_shader.setVec3("materials[4].color", 0.5f, 0.5f, 1.0f);    // 紫色

    path_shader.setVec3("materials[5].color", 1.0f, 1.0f, 1.0f);    // 镜面反射
    path_shader.setFloat("materials[5].specularRate", 1.0f);
    path_shader.setFloat("materials[5].refractRate", 0.0f);

    path_shader.setVec3("materials[6].color", 1.0f, 1.0f, 1.0f);    // 折射
    path_shader.setFloat("materials[6].specularRate", 0.1f);
    path_shader.setFloat("materials[6].refractRate", 1.0f);
    path_shader.setFloat("materials[6].refractAngle", 0.1f);

    // 第一个球，散射
    path_shader.setVec3("spheres[0].center", -1.35f, -1.4f, 2.0f);
    path_shader.setFloat("spheres[0].radius", 0.6f);
    path_shader.setUInt("spheres[0].material_id", 0);

    // 第二个球， 镜面反射
    path_shader.setVec3("spheres[1].center", 0.f, -1.4f, 2.0f);
    path_shader.setFloat("spheres[1].radius", 0.6f);
    path_shader.setUInt("spheres[1].material_id", 6);

    // 第二个球， 折射
    path_shader.setVec3("spheres[2].center", 1.35f, -1.4f, 2.0f);
    path_shader.setFloat("spheres[2].radius", 0.6f);
    path_shader.setUInt("spheres[2].material_id", 5);

    // 后面
    path_shader.setVec3("tris[0].p0", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[0].p1", -2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[0].p2", 2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[0].n0", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tris[0].n1", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tris[0].n2", 0.0f, 0.0f, 1.0f);
    path_shader.setUInt("tris[0].material_id", 4);

    path_shader.setVec3("tris[1].p0", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[1].p1", 2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[1].p2", 2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[1].n0", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tris[1].n1", 0.0f, 0.0f, 1.0f);
    path_shader.setVec3("tris[1].n2", 0.0f, 0.0f, 1.0f);
    path_shader.setUInt("tris[1].material_id", 4);

    // 左侧面
    path_shader.setVec3("tris[2].p0", -2.0f, 2.0f, 4.0f);
    path_shader.setVec3("tris[2].p1", -2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[2].p2", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[2].n0", 1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[2].n1", 1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[2].n2", 1.0f, 0.0f, 0.0f);
    path_shader.setUInt("tris[2].material_id", 2);

    path_shader.setVec3("tris[3].p0", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[3].p1", -2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[3].p2", -2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[3].n0", 1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[3].n1", 1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[3].n2", 1.0f, 0.0f, 0.0f);
    path_shader.setUInt("tris[3].material_id", 2);

    // 右侧面
    path_shader.setVec3("tris[4].p0", 2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[4].p1", 2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[4].p2", 2.0f, 2.0f, 4.0f);
    path_shader.setVec3("tris[4].n0", -1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[4].n1", -1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[4].n2", -1.0f, 0.0f, 0.0f);
    path_shader.setUInt("tris[4].material_id", 3);

    path_shader.setVec3("tris[5].p0", 2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[5].p1", 2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[5].p2", 2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[5].n0", -1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[5].n1", -1.0f, 0.0f, 0.0f);
    path_shader.setVec3("tris[5].n2", -1.0f, 0.0f, 0.0f);
    path_shader.setUInt("tris[5].material_id", 3);

    // 上面
    path_shader.setVec3("tris[6].p0", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[6].p1", 2.0f, 2.0f, 4.0f);
    path_shader.setVec3("tris[6].p2", -2.0f, 2.0f, 4.0f);
    path_shader.setVec3("tris[6].n0", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[6].n1", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[6].n2", 0.0f, -1.0f, 0.0f);
    path_shader.setUInt("tris[6].material_id", 0);

    path_shader.setVec3("tris[7].p0", -2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[7].p1", 2.0f, 2.0f, 0.0f);
    path_shader.setVec3("tris[7].p2", 2.0f, 2.0f, 4.0f);
    path_shader.setVec3("tris[7].n0", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[7].n1", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[7].n2", 0.0f, -1.0f, 0.0f);
    path_shader.setUInt("tris[7].material_id", 0);

    // 下面
    path_shader.setVec3("tris[8].p0", -2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[8].p1", -2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[8].p2", 2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[8].n0", 0.0f, 1.0f, 0.0f);
    path_shader.setVec3("tris[8].n1", 0.0f, 1.0f, 0.0f);
    path_shader.setVec3("tris[8].n2", 0.0f, 1.0f, 0.0f);
    path_shader.setUInt("tris[8].material_id", 0);

    path_shader.setVec3("tris[9].p0", -2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[9].p1", 2.0f, -2.0f, 4.0f);
    path_shader.setVec3("tris[9].p2", 2.0f, -2.0f, 0.0f);
    path_shader.setVec3("tris[9].n0", 0.0f, 1.0f, 0.0f);
    path_shader.setVec3("tris[9].n1", 0.0f, 1.0f, 0.0f);
    path_shader.setVec3("tris[9].n2", 0.0f, 1.0f, 0.0f);
    path_shader.setUInt("tris[9].material_id", 0);

    // 顶部光源
    path_shader.setVec3("tris[10].p0", -0.8f, 2.0f, 1.2f);
    path_shader.setVec3("tris[10].p1", 0.8f, 2.0f, 2.8f);
    path_shader.setVec3("tris[10].p2", -0.8f, 2.0f, 2.8f);
    path_shader.setVec3("tris[10].n0", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[10].n1", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[10].n2", 0.0f, -1.0f, 0.0f);
    path_shader.setUInt("tris[10].material_id", 1);

    path_shader.setVec3("tris[11].p0", -0.8f, 2.0f, 1.2f);
    path_shader.setVec3("tris[11].p1", 0.8f, 2.0f, 1.2f);
    path_shader.setVec3("tris[11].p2", 0.8f, 2.0f, 2.8f);
    path_shader.setVec3("tris[11].n0", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[11].n1", 0.0f, -1.0f, 0.0f);
    path_shader.setVec3("tris[11].n2", 0.0f, -1.0f, 0.0f);
    path_shader.setUInt("tris[11].material_id", 1);

    Render render(SCR_WIDTH, SCR_HEIGHT);

    unsigned int frame_count = 0;
    const unsigned int frame_time_constraint = 20;   // 每帧最少要花费的时间，ms
    while (!glfwWindowShouldClose(window))
    {
        time_t begin = clock();
        frame_count ++;
        //printf("%d ", frame_count);
        processInput(window);

        glClearColor(0.f, 0.0f, 0.f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        path_shader.bind();
        path_shader.setUInt("frame_count", frame_count);
        render.draw(path_shader);

        time_t end = clock();
        if(end - begin < frame_time_constraint)
        {
            Sleep(frame_time_constraint - end + begin);
        }

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
