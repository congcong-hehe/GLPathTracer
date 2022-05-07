#version 330 core

#define WIDTH 600
#define HEIGHT 600

#define DEPTH 5

#define INFINITY 100000000.0
#define PI 3.141592653
#define EPSILON 0.00001
#define PDF (1.0 / (2 * PI))

struct Material
{
    vec3 emissive;    // 是否发光
    vec3 baseColor; // 基本颜色
    float metallic; // 金属度，漫反射的比例
    float specular;     // 镜面反射的强度
    float specularTint;     // 控制镜面反射的颜色，在baseColor和vec(1)之间插值
    float roughness;    // 粗糙度
};

float SchlickFresnel(float u)
{
    float m = clamp(1-u, 0, 1);
    float m2 = m * m;
    return m2 * m2 * m;
}

float GTR1(float NdotH, float a) {
    if (a >= 1) return 1/PI;
    float a2 = a*a;
    float t = 1 + (a2-1)*NdotH*NdotH;
    return (a2-1) / (PI*log(a2)*t);
}

float GTR2(float NdotH, float a) {
    float a2 = a*a;
    float t = 1 + (a2-1)*NdotH*NdotH;
    if(t == 0.0) return 0.0;
    return a2 / (PI * t*t);
}

float smithG_GGX(float NdotV, float alphaG) {
    float a = alphaG*alphaG;
    float b = NdotV*NdotV;
    return 1 / (NdotV + sqrt(a + b - a*b));
}

// https://github.com/wdas/brdf/blob/main/src/brdfs/disney.brdf
// https://media.disneyanimation.com/uploads/production/publication_asset/48/asset/s2012_pbs_disney_brdf_notes_v3.pdf
// 只实现漫反射和镜面反射
vec3 brdf(vec3 V, vec3 N, vec3 L, in Material material)
{
    // 预计算常用数值
    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    if(NdotL < 0 || NdotV < 0) return vec3(0);
    vec3 H = normalize(L + V);
    float NdotH = dot(N, H);
    float LdotH = dot(L, H);

    vec3 Cdlin = material.baseColor;
    float Cdlum = 0.3 * Cdlin.r + 0.6 * Cdlin.g  + 0.1 * Cdlin.b;
    vec3 Ctint = (Cdlum > 0) ? (Cdlin/Cdlum) : (vec3(1)); 
    vec3 Cspec = material.specular * mix(vec3(1), Ctint, material.specularTint);
    vec3 Cspec0 = mix(0.08*Cspec, Cdlin, material.metallic); // 0° 镜面反射颜色

    // 漫反射
    float Fd90 = 0.5 + 2.0 * LdotH * LdotH * material.roughness;
    float FL = SchlickFresnel(NdotL);
    float FV = SchlickFresnel(NdotV);
    float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
    vec3 diffuse = Fd * Cdlin / PI;

    // 镜面反射
    float alpha = material.roughness * material.roughness;
    float Ds = GTR2(NdotH, alpha);
    float FH = SchlickFresnel(LdotH);
    vec3 Fs = mix(Cspec0, vec3(1), FH);
    float Gs = smithG_GGX(NdotL, material.roughness);
    Gs *= smithG_GGX(NdotV, material.roughness);
    vec3 specular = Gs * Fs * Ds;
    
    return diffuse * (1.0 - material.metallic) + specular;
}

struct Ray
{
    vec3 ori;
    vec3 dir;
};

vec3 pointAt(float t, Ray ray)
{
    return ray.ori + t * ray.dir;
}

struct Camera
{
    vec3 ori;
    vec3 horizontal;
    vec3 vertical;
    vec3 lower_left_corner;
};

struct Sphere
{
    vec3 center;
    float radius;
    uint material_id;
};

struct Triangle
{
    vec3 p0, p1, p2;    // 位置
    vec3 n0, n1, n2;    // 法线
    uint material_id;
};

struct Intersection
{
    vec3 position;
    float t;
    vec3 normal;
    Material material;
};

uniform Material materials[8];
uniform uint frame_count;
uniform sampler2D imgTex;
uniform Camera camera;
uniform Sphere spheres[3];
uniform Triangle tris[12];

in vec2 TexCoords;
out vec4 FragColor;

uint static_seed;

// 生成随机数https://blog.demofox.org/2020/05/25/casual-shadertoy-path-tracing-1-basic-camera-diffuse-emissive/
uint seed = uint(
    uint((gl_FragCoord.x * 0.5 + 0.5) * WIDTH)  * uint(1973) + 
    uint((gl_FragCoord.y * 0.5 + 0.5) * HEIGHT) * uint(9277) + 
    uint(frame_count + static_seed) * uint(26699)) | uint(1);

uint wang_hash(inout uint seed) {
    seed = uint(seed ^ uint(61)) ^ uint(seed >> uint(16));
    seed *= uint(9);
    seed = seed ^ (seed >> 4);
    seed *= uint(0x27d4eb2d);
    seed = seed ^ (seed >> 15);
    return seed;
}
 
float rand() {
    static_seed ++;
    return float(wang_hash(seed)) / 4294967296.0;
}

// 半球面均匀采样
vec3 sampleHemisphere()
{
    float z = rand();
    float r = max(0, sqrt(1 - z*z));
    float phi = 2.0 * PI * rand();
    return vec3(r * cos(phi), r * sin(phi), z);
}

// 将半球上的光线方向转换为世界方向
vec3 toWorld(vec3 v, vec3 normal)
{
    vec3 B, C;
	if (abs(normal.x) > abs(normal.y))
	{
		float inv_len = 1.0 / sqrt(normal.x * normal.x + normal.z * normal.z);
		C = vec3(normal.z * inv_len, 0.0f, -normal.x * inv_len);
	}
	else
	{
		float inv_len = 1.0f / sqrt(normal.y * normal.y + normal.z * normal.z);
		C = vec3(0.0f, normal.z * inv_len, -normal.y * inv_len);
	}
	B = cross(C, normal);
	return B * v.x + C * v.y + normal * v.z;
}

vec3 SampleGTR2(vec3 V, vec3 N, float alpha) {
    
    float xi_1 = rand();
    float xi_2 = rand();
    float phi_h = 2.0 * PI * xi_1;
    float sin_phi_h = sin(phi_h);
    float cos_phi_h = cos(phi_h);

    float cos_theta_h = sqrt((1.0-xi_2)/(1.0+(alpha*alpha-1.0)*xi_2));
    float sin_theta_h = sqrt(max(0.0, 1.0 - cos_theta_h * cos_theta_h));

    // 采样 "微平面" 的法向量 作为镜面反射的半角向量 h 
    vec3 H = vec3(sin_theta_h*cos_phi_h, sin_theta_h*sin_phi_h, cos_theta_h);
    H = toWorld(H, N);   // 投影到真正的法向半球

    // 根据 "微法线" 计算反射光方向
    vec3 L = reflect(-V, H);

    return L;
}

float sqr(float x) { 
    return x*x; 
}

vec3 sampleBRDF(vec3 V, vec3 N, in Material material)
{
    float alpha_GTR2 = max(0.001, sqr(material.roughness));

    float p_diffuse = 1.0 - material.metallic;
    float p_specular = material.metallic;

    float r3 = rand();

    if(r3 < p_diffuse)
    {
        return toWorld(sampleHemisphere(), N);
    }
    else
    {
        return SampleGTR2(V, N, alpha_GTR2);
    }
}

float pdfBRDF(vec3 V, vec3 N, vec3 L, in Material material)
{
    float NdotL = dot(N, L);
    float NdotV = dot(N, V);
    if(NdotL < 0 || NdotV < 0) return 0;

    vec3 H = normalize(L + V);
    float NdotH = dot(N, H);
    float LdotH = dot(L, H);

    float alpha = max(0.001, sqr(material.roughness));
    float Ds = GTR2(NdotH, alpha); 

    float pdf_diffuse = NdotL / PI;
    float pdf_specular = Ds * NdotH / (4.0 * dot(L, H));

    float p_diffuse = 1.0 - material.metallic;
    float p_specular = material.metallic;

    float pdf = p_diffuse   * pdf_diffuse + p_specular * pdf_specular;
    return max(0, pdf);
}

bool hitSphere(Ray ray, Sphere sphere, float t_min, float t_max, out Intersection inter)
{
    vec3 oc = ray.ori - sphere.center;
    float a = dot(ray.dir, ray.dir);
    float h = dot(oc, ray.dir);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;
    float discriminant = h * h - a * c;

    if(discriminant < 0)
    {
        return false;
    }

    float sqrtd = sqrt(discriminant);
    float root = (-h - sqrtd) / a;
    if(root < t_min || root > t_max)
    {
        root = (-h + sqrtd) / a;
        if(root < t_min || root > t_max)
        {
            return false;
        }
    }

    inter.t = root;
    inter.position = pointAt(root, ray);
    inter.normal = (inter.position - sphere.center) / sphere.radius;
    inter.material = materials[sphere.material_id];

    if(dot(inter.normal, ray.dir) > 0)  // 如果光源打到球的内部
    {
        inter.normal = -inter.normal;
    }

    return true;
}

bool hitTriangle(Ray ray, Triangle tri, float t_min, float t_max, out Intersection inter)
{
    vec3 edge1 = tri.p1 - tri.p0;
    vec3 edge2 = tri.p2 - tri.p0;

    vec3 s = ray.ori - tri.p0;
    vec3 s1 = cross(ray.dir, edge2);
    vec3 s2 = cross(s, edge1);

    float a = dot(s1, edge1);
    if(a < EPSILON)
        return false;

    float b1 = dot(s1, s);
    if(b1 < 0 || b1 > a)
        return false;

    float b2 = dot(s2, ray.dir);
    if(b2 < 0 || b1 + b2 > a)
        return false;

    float inv_a = 1.0 / a;

    float t = dot(s2, edge2) * inv_a;
    if(t < EPSILON || t < t_min || t > t_max)
        return false;

    b1 *= inv_a;
    b2 *= inv_a;

    vec3 norm = tri.n0;
    if(dot(norm, ray.dir) > 0)
        return false;
    
    inter.t = t;
    inter.position = pointAt(t, ray);
    inter.material = materials[tri.material_id];
    inter.normal = norm;

    return true;
}

bool hitWorld(Ray ray, out Intersection inter)
{
    float closet_inter_t = INFINITY;
    bool if_tag = false;
    for(int i = 0; i < 12; ++i)
    {
        Intersection inter_temp;
        if(hitTriangle(ray, tris[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter_temp.t;
            inter = inter_temp;
        }
    }
    for(int i = 0; i < 3; ++i)
    {
        Intersection inter_temp;
        if(hitSphere(ray, spheres[i], 0, closet_inter_t, inter_temp))
        {
            if_tag = true;
            closet_inter_t = inter_temp.t;
            inter = inter_temp;
        }
    }

    return if_tag;
}

vec3 trace(Intersection inter, Ray ray)
{
    vec3 indir_filtration = vec3(1);
    vec3 result = vec3(0);

    if(inter.material.emissive != vec3(0))
        return inter.material.emissive;

    for(int i = 0; i < DEPTH; ++i)
    {
        vec3 V = -ray.dir;
        vec3 N = inter.normal;
        vec3 L = sampleBRDF(V, N, inter.material);
        float NdotL = dot(L, inter.normal);
        if(NdotL <= 0.0) break;
        
        vec3 f_r = brdf(V, N, L, inter.material);
        float pdf = pdfBRDF(V, N, L, inter.material);
        indir_filtration *= f_r * NdotL / pdf;

        ray.dir = L;
        ray.ori = inter.position;
        
        Intersection new_inter;
        if(!hitWorld(ray, new_inter))
        {
            result += vec3(0.5) * indir_filtration;
            break;
        }
        
        result += new_inter.material.emissive * indir_filtration;
        inter = new_inter;
    }

    return result;
}


void main()
{
    float u = (gl_FragCoord.x - 0.5 + rand()) / (WIDTH - 1);
    float v = (gl_FragCoord.y - 0.5 + rand()) / (HEIGHT - 1);
    Ray ray;
    ray.ori = camera.ori;
    ray.dir = normalize(camera.lower_left_corner + u * camera.horizontal + v * camera.vertical - camera.ori);

    vec3 color = vec3(0);
    int spp = 10;
    static_seed = 0u;
    for(int i = 0; i < spp; ++i)
    {
        Intersection inter;
        if(hitWorld(ray, inter))
        {
            color += trace(inter, ray) / spp;
        }
    }

    vec3 textureColor = texture(imgTex, TexCoords).rgb;
    FragColor = vec4(mix(textureColor, color, 1.0 / float(frame_count)), 1.0);
}