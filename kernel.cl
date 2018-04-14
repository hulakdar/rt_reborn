/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   kernel.cl                                          :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/22 13:33:31 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/22 13:33:31 by skamoza          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#define KERNEL_ONLY
#include "kernel.h"

static constant t_object	objs[] = {
	{{1,0,0}, {1,1,1}, 1, sphere, {.sphere = (t_sphere){{0,17,45}, 5, 100}}},
	{{1,0,0}, {1,0,1}, 0, sphere, {.sphere = (t_sphere){{-8,-8,44}, 6, 100}}},
	{{1,0,0}, {1,0,1}, 0, sphere, {.sphere = (t_sphere){{0,0,270}, 200, 4}}},
	{{1,0,0}, {0,1,1}, 0, sphere, {.sphere = (t_sphere){{215,0,55}, 200, 4}}},
	{{1,0,0}, {1,1,0}, 0, sphere, {.sphere = (t_sphere){{-215,0,55}, 200, 100}}},
	{{1,0,0}, {1,0,0}, 0, sphere, {.sphere = (t_sphere){{0,215,55}, 200, 4}}},
	{{1,0,0}, {1,1,1}, 0, sphere, {.sphere = (t_sphere){{0,-210,55}, 200, 100}}},
	{{0,1,0}, {1,1,1}, 0, sphere, {.sphere = (t_sphere){{7,-5,45}, 6, 100}}},
	{{0,0,1}, {1,1,1}, 0, sphere, {.sphere = (t_sphere){{-8,0,55}, 7, 4}}},
	{{1,0,0}, {0,0,1}, 0, plane, {.plane = (t_plane){{8,0,55}, {-1, 1, -1}}}},
	{{0,0,1}, {0,1,1}, 0, cylinder, {.cylinder = (t_cylinder){{-8,-10,35}, {0,1,0}, 4, 16, 16}}},
	{{0,0,1}, {0,1,1}, 0, cone, {.cone = (t_cone){{8,0,35}, {0,1,0}, 0.5, -7, 7}}},
	{{1,0,0}, {1,1,0}, 0, disk, {.disk = (t_disk){{0,0,25}, {1, 1, 1}, 9}}},
	{{0,0,1}, {0,1,0}, 0, torus, {.torus = (t_torus){{0,-8,35}, {0, 1, 0}, 25, 1}}},
	{{0,0,1}, {1,0,0}, 0, triangle, {.triangle = (t_triangle){{0,0,15}, {5, 0, 15}, {3, -5, 45}}}},
	//{{0,0,1}, {1,0,0}, 0, mobius, {.mobius = (t_mobius){5, 1}}}
};

static constant t_camera 	camera = {
	{0,0,0}, {0,0,1}, {1,1,1}, {500, 500}
	//{4,0,-20}, {0,0,1}, {1,1,1}, {500, 500} /*for mobius*/
};

static constant float epsilon = 1e-8;

static float4	to_quaternion(float3 a)
{
	a *= 0.5f;
	float3 c = native_cos(a);
	a = native_sin(a);

	return ((float4)(	c.z * c.y * c.x + a.z * a.y * a.x,
						c.z * a.y * c.x - a.z * c.y * a.x,
						c.z * c.y * a.x + a.z * a.y * c.x,
						a.z * c.y * c.x - c.z * a.y * a.x));
}

static float3	rotate_by_quaternion(float4 q, float3 vtx)
{
	return (vtx + 2.0f * cross(q.xyz, cross(q.xyz, vtx) + q.w * vtx));
}

static float get_random(unsigned int *seed0, unsigned int *seed1) {

	/* hash the seeds using bitwise AND operations and bitshifts */
	*seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);
	*seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);

	unsigned int ires = ((*seed0) << 16) + (*seed1);

	/* use union struct to convert int to float */
	union {
		float f;
		unsigned int ui;
	} res;

	res.ui = (ires & 0x007fffff) | 0x40000000;  /* bitwise AND, bitwise OR */
	return half_divide((res.f - 2.0f), 2.0f);
}

static void ft_roots(float2 *t, float a, float b, float c)
{
	float	deskr;

	deskr = b * b - 4 * a * c;
	if (deskr >= 0.f && a != 0.f)
		*t = (float2)(	native_divide(-b + native_sqrt(deskr), 2 * a),
						native_divide(-b - native_sqrt(deskr), 2 * a));
	else
		*t = (float2)(-1, -1);
}

static float  sphere_intersect(constant t_sphere *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float	a;
	float	b;
	float	c;
	float3	oc;
	float2	t;

	oc = ray_origin - obj->origin;
	a = dot(ray_dir, ray_dir);
	b = 2 * dot(ray_dir, oc);
	c = dot(oc, oc) - (obj->radius * obj->radius);
	ft_roots(&t, a, b, c);
	if ((t.x < 0.0 && t.y >= 0.0) || (t.y < 0.0 && t.x >= 0.0))
		return t.x > t.y ? t.x : t.y;
	else
		return t.x < t.y ? t.x : t.y;
}

static float3	sphere_normal(constant t_sphere *obj, float3 pos)
{
	return (normalize(pos - obj->origin));
}

static float  plane_intersect(constant t_plane *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float	denom;
	float3	oc;

	if ((denom = dot(ray_dir, obj->normal)) == 0)
		return (-1);
	oc = ray_origin - obj->origin;
	return (-dot(oc, obj->normal) / denom);
}

static float3	plane_normal(constant t_plane *obj)
{
	return (normalize(obj->normal));
}

static float  cylinder_intersect(constant t_cylinder *obj,
								float3 ray_dir,
								float3 ray_origin,
								float *m)
{
	float	a;
	float	b;
	float	c;
	float3	oc;
	float2	t;

	oc = ray_origin - obj->origin;
	t.x = dot(ray_dir, normalize(obj->normal));
	t.y = dot(oc, normalize(obj->normal));
	a = dot(ray_dir, ray_dir) - t.x * t.x;
	b = 2 * (dot(ray_dir, oc) - t.x * t.y);
	c = dot(oc, oc) - t.y * t.y - obj->r2;
	ft_roots(&t, a, b, c);
	if ((t.x  < 0.0f) && (t.y < 0.0f))
		return (-1);
	if ((t.x  < 0.0f) || (t.y < 0.0f))
	{
		a = (t.x > t.y) ? t.x : t.y;
		*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
		return ((*m <= obj->height) && (*m >= 0) ? t.x : -1);
	}
	a = (t.x < t.y) ? t.x : t.y;
	*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
	if ((*m <= obj->height) && (*m >= 0))
		return (a);
	a = (t.x >= t.y) ? t.x : t.y;
	*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
	if ((*m <= obj->height) && (*m >= 0))
		return (a);
	return (-1);
}

static float3	cylinder_normal(constant t_cylinder *obj, float3 pos, float m)
{
	return (normalize(pos - obj->origin - fast_normalize(obj->normal) * m));
}

static float  cone_intersect(constant t_cone *obj,
								float3 ray_dir,
								float3 ray_origin,
								float *m)
{
	float	a;
	float	b;
	float	c;
	float 	d;
	float3	oc;
	float2	t;

	oc = ray_origin - obj->origin;
	t.x = dot(ray_dir, normalize(obj->normal));
	t.y = dot(oc, normalize(obj->normal));
	d = 1 + obj->half_tangent * obj->half_tangent;
	a = dot(ray_dir, ray_dir) - d * t.x * t.x;
	b = 2 * (dot(ray_dir, oc) - d * t.x * t.y);
	c = dot(oc, oc) - d * t.y * t.y;
	ft_roots(&t, a, b, c);
	if ((t.x  < 0.0f) && (t.y < 0.0f))
		return (-1);
	if ((t.x  < 0.0f) || (t.y < 0.0f))
	{
		a = (t.x > t.y) ? t.x : t.y;
		*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
		return ((*m <= obj->m2) && (*m >= obj->m1) ? t.x : -1);
	}
	a = (t.x < t.y) ? t.x : t.y;
	*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
	if ((*m <= obj->m2) && (*m >= obj->m1))
		return (a);
	a = (t.x >= t.y) ? t.x : t.y;
	*m  = dot(ray_dir, normalize(obj->normal)) * a + dot(oc, fast_normalize(obj->normal));
	if ((*m <= obj->m2) && (*m >= obj->m1))
		return (a);
	return (-1);
}

static float3	cone_normal(constant t_cone *obj, float3 pos, float m)
{
	return (normalize(pos - obj->origin - normalize(obj->normal) * m * (1 + obj->half_tangent * obj->half_tangent)));
}

static float  disk_intersect(constant t_disk *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float	denom;
	float3	oc;
	float	t;
	float3 	pos;

	if ((denom = dot(ray_dir, obj->normal)) == 0)
		return (-1);
	oc = ray_origin - obj->origin;
	t = -dot(oc, obj->normal) / denom;
	if (t < 0)
		return (-1.0f);
	pos = ray_origin + t * ray_dir;
	pos -= obj->origin;
	if (dot(pos, pos) <= obj->radius2)
		return (t);
	return (-1);
}

static float3	disk_normal(constant t_disk *obj)
{
	return (normalize(obj->normal));
}

static void	fourth_degree_equation(float4 *t, float A, float B, float C, float D, float E)
{
	float a = -3.0f * B * B / 8.0f / A / A + C / A;
	float b = B * B * B / 8 / A / A / A - B * C / 2 / A / A + D / A;
	float g = - 3.0f * B * B * B * B / 256.0f / A / A / A / A + C * B * B / 16.0f / A / A / A - B * D / 4.0f / A / A + E / A;
	float P = -a * a / 12.0f - g;
	float Q = -a * a * a / 108.0f + a * g / 3.0f - b * b / 8.0f;
	float R = Q / 2.0f + sqrt(Q * Q / 4.0f + P * P * P / 27.0f);
	float U = cbrt(R);
	float U2;
	U2 = (U == 0.0f) ? 0.0f : P / 3.0f / U;
	float y = -5.0f / 6.0f * a - U + U2;
	float W = sqrt(a + 2.0f * y);
	(*t)[0] = -B / 4.0f / A + (W + sqrt(-(3.0f * a + 2.0f * y + 2.0f * b / W))) / 2.0f;
	(*t)[1] = -B / 4.0f / A + (W - sqrt(-(3.0f * a + 2.0f * y + 2.0f * b / W))) / 2.0f;
	(*t)[2] = -B / 4.0f / A + (-W + sqrt(-(3.0f * a + 2.0f * y - 2.0f * b / W))) / 2.0f;
	(*t)[3] = -B / 4.0f / A + (-W - sqrt(-(3.0f * a + 2.0f * y - 2.0f * b / W))) / 2.0f;
}

static float  torus_intersect(constant t_torus *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float3	oc;
	float	a;
	float	b;
	float	c;
	float	d;
	float	e;
	float	m;
	float	n;
	float	o;
	float	p;
	float	q;
	float4	t;
	int 	i;
	float 	ret;

	oc = ray_origin - obj->origin;
	m = dot(ray_dir, ray_dir);
	n = dot(ray_dir, oc);
	o = dot(oc, oc);
	p = dot(ray_dir, obj->normal);
	q = dot(oc, obj->normal);
	a = m * m;
	b = 4.0f * m * n;
	c = 4.0f * n * n + 2.0f * m * o - 2.0f * (obj->big_radius2 + obj->small_radius2) * m + 4.0f * obj->big_radius2 * p * p;
	d = 4.0f * n * o - 4.0f * (obj->big_radius2 + obj->small_radius2) * n + 8.0f * obj->big_radius2 * p * q;
	e = o * o - 2.0f * (obj->big_radius2 + obj->small_radius2) * o + 4.0f * obj->big_radius2 * q * q + (obj->big_radius2 - obj->small_radius2) * (obj->big_radius2 - obj->small_radius2);
	fourth_degree_equation(&t, a, b, c, d, e);
	i = 0;
	ret = 1000.0f;
	while (i < 4)
	{
		ret = (t[i] >= 0 && t[i] < ret) ? t[i] : ret;
		i++;
	}
	return ((ret < 999.0f) ? ret : -1);
}

static float3	torus_normal(constant t_torus *obj, float3 pos)
{
	float 	k;
	float3	a;
	float 	m;

	k = dot(pos - obj->origin, obj->normal);
	a = pos - obj->normal * k;
	m = sqrt(obj->small_radius2 - k * k);
	return (normalize(pos - a - (obj->origin - a) * m / (sqrt(obj->big_radius2) + m)));
}

static float  triangle_intersect(constant t_triangle *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float	denom;
	float3	oc;
	float3	normal;
	float 	t;
	float3	p;
	float3	edge0;
	float3	edge1;
	float3	edge2;
	float3	c0;
	float3	c1;
	float3	c2;

	edge0 = obj->vertex1 - obj->vertex0;
	edge1 = obj->vertex2 - obj->vertex1;
	edge2 = obj->vertex0 - obj->vertex2;
	normal = normalize(cross(edge0, edge1));

	if ((denom = dot(ray_dir, normal)) == 0)
		return (-1);
	oc = ray_origin - obj->vertex0;
	t = -dot(oc, normal) / denom;
	if (t < 0)
		return (-1);
	p = ray_origin + ray_dir * t;
	c0 = p - obj->vertex0;
	c1 = p - obj->vertex1;
	c2 = p - obj->vertex2;
	if (dot(normal, cross(edge0, c0)) > 0 && dot(normal, cross(edge1, c1)) > 0 && dot(normal, cross(edge2, c2)) > 0)
		return (t);
	return (-1);
}

static float3	triangle_normal(constant t_triangle *obj)
{
	return (normalize(cross(obj->vertex1 - obj->vertex0, obj->vertex2 - obj->vertex1)));
}

static float	third_degree_equation(float A, float B, float C, float D)
{
	float p = (3.0f * A * C - B * B) / 3.0f/ A / A;
	float q = (2 * B * B * B - 9 * A * B * C + 27.0f * A * A * D) / 27.0f / A / A / A;
	float d = pow(p / 3.0f, 3) + pow(q / 2.0f, 2);
	if (d < 0.0f)
		return (-1);
	float a = cbrt(-q / 2.0f + sqrt(d));
	float b = cbrt(-q / 2.0f - sqrt(d));
	float y = a + b; 
	float x = y - B / 3.0f / A;
	return (x);
}

int dblsgn(float x)
{
	return (x < -epsilon) ? (-1) : (x > epsilon); 
}

bool inside(float3 pt, constant t_mobius *obj)
{
	float x = pt.x;
	float y = pt.y;
	float z = pt.z;
	float t = atan2(y, x);
	float s;
	if (dblsgn(sin(t / 2)) != 0)
	{
		s = z / sin(t / 2);
	}
	else
	{
		if (dblsgn(cos(t)) != 0)
		{
			s = (x / cos(t) - obj->radius) / cos(t / 2);
		}
		else
		{
			s = (y / sin(t) - obj->radius) / cos(t / 2);
		}
	}
	x -= (obj->radius + s * cos(t / 2)) * cos(t);
	y -= (obj->radius + s * cos(t / 2)) * sin(t);
	z -= s * sin(t / 2);
	if (dblsgn(x * x + y * y + z * z) != 0)
	{
		return false;
	}	
	return (s >= -obj->half_width - epsilon  && s <= obj->half_width + epsilon);
}

static float  mobius_intersect(constant t_mobius *obj,
								float3 ray_dir,
								float3 ray_origin)
{
	float ox = ray_origin.x;
	float oy = ray_origin.y;
	float oz = ray_origin.z;
	float dx = ray_dir.x;
	float dy = ray_dir.y;
	float dz = ray_dir.z;
	float R = obj->radius;
		
	float coef_0 = 0;
	float coef_1 = 0;
	float coef_2 = 0;
	float coef_3 = 0;

	coef_0 = ox * ox * oy + oy * oy * oy - 2 * ox * ox * oz - 2 * oy * oy * oz + oy * oz * oz - 2 * ox * oz * R - oy * R * R;
	coef_1 = dy * ox * ox - 2 * dz * ox * ox + 2 * dx * ox * oy + 3 * dy * oy * oy - 2 * dz * oy * oy - 4 * dx * ox * oz - 4 * dy * oy * oz + 2 * dz * oy * oz + dy * oz * oz - 2 * dz * ox * R - 2 * dx * oz * R - dy * R * R;
	coef_2 = 2 * dx * dy * ox - 4 * dx * dz * ox + dx * dx * oy + 3 * dy * dy * oy - 4 * dy * dz * oy + dz * dz * oy - 2 * dx * dx * oz - 2 * dy * dy * oz + 2 * dy * dz * oz - 2 * dx * dz * R;
	coef_3 = dx * dx * dy + dy * dy * dy - 2 * dx * dx * dz - 2 * dy * dy * dz + dy * dz * dz;
	float t = third_degree_equation(coef_3, coef_2, coef_1, coef_0);
	float3 pos = ray_origin + t * ray_dir;
	if (t > epsilon && inside(pos, obj))
		return (t);
	return (-1);
}

static float3	mobius_normal(constant t_mobius *obj, float3 pos)
{
	float x = pos.x;
	float y = pos.y;
	float z = pos.z;
	float R = obj->radius;
	float3 ret =  {2 * x * y - 2 * R * z - 4 * x * z, -R * R + x * x + 3 * y * y - 4 * y * z + z * z, -2 * R * x - 2 * x * x - 2 * y * y + 2 * y * z};
	return (normalize(ret));
}

static void		intersect(	constant t_object *obj,
							float3 ray_dir,
							float3 ray_orig,
							constant t_object **closest,
							float	*closest_dist,
							float 	*m)
{
	float current;
	switch (obj->type) {
		case sphere:
			current = sphere_intersect(&obj->spec.sphere, ray_dir, ray_orig);
			break;
		case plane:
			current = plane_intersect(&obj->spec.plane, ray_dir, ray_orig);
			break;
		case cylinder:
			current = cylinder_intersect(&obj->spec.cylinder, ray_dir, ray_orig, m);
			break;
		case cone:
			current = cone_intersect(&obj->spec.cone, ray_dir, ray_orig, m);
			break;
		case disk:
			current = disk_intersect(&obj->spec.disk, ray_dir, ray_orig);
			break;
		case torus:
			current = torus_intersect(&obj->spec.torus, ray_dir, ray_orig);
			break;
		case triangle:
			current = triangle_intersect(&obj->spec.triangle, ray_dir, ray_orig);
			break;
		case mobius:
			current = mobius_intersect(&obj->spec.mobius, ray_dir, ray_orig);
			break;
		default:
			break;
	}
	if (current <= 0.0 || current > *closest_dist)
		return ;
	*closest_dist = current;
	*closest = obj;
}

static float3	random_path_sphere(constant t_sphere	*obj, t_hit *hit, float *magnitude)
{
	float u1 = get_random(&hit->seeds[0], &hit->seeds[1]);
	float u2 = get_random(&hit->seeds[0], &hit->seeds[1]);
	const float phi = 2.f * M_PI * u2;
	const float zz = 1.f - 2.f * u1;
	const float r = sqrt(max(0.f, 1.f - zz * zz));
	const float xx = r * cos(phi);
	const float yy = r * sin(phi);
	float3 point = (float3)(xx, yy, zz) * (obj->radius + 0.03f);

	if (dot(point, obj->origin - hit->pos) > 0.0f)
		point = -point;
	point = point + obj->origin;
	float3 dir = point - hit->pos;
	*magnitude = length(dir);
	return (dir / *magnitude);
}

static float3	find_direct(constant t_object *obj, constant t_object *objs, int objnum, t_hit *hit)
{
	constant t_object	*closest = NULL;

	float magnitude = 0;
	float3 ray_dir = random_path_sphere(&obj->spec.sphere, hit, &magnitude);
	for (int i = 0; i < objnum; i++)
	{
		float	closest_dist = MAXFLOAT;
		intersect(&objs[i], ray_dir, hit->pos, &closest, &closest_dist, &(hit->m));
		if (closest_dist < magnitude)
			return ((float3)(0,0,0));
	}
	return ((float3)(obj->emission));
	
}

static float3	find_normal(constant t_object *obj, float3 ray_orig, float m)
{
	switch (obj->type) {
		case sphere:
			return (sphere_normal(&obj->spec.sphere, ray_orig));
		case plane:
			return (plane_normal(&obj->spec.plane));
		case cylinder:
			return (cylinder_normal(&obj->spec.cylinder, ray_orig, m));
		case cone:
			return (cone_normal(&obj->spec.cone, ray_orig, m));
		case disk:
			return (disk_normal(&obj->spec.disk));
		case torus:
			return (torus_normal(&obj->spec.torus, ray_orig));
		case triangle:
			return (triangle_normal(&obj->spec.triangle));
		case mobius:
			return (mobius_normal(&obj->spec.mobius, ray_orig));
		default:
			break;
	}
	return ((float3)(0,0,0));
}

static void	trace_ray(float3 ray_orig, float3 ray_dir, /*t_scene scene,*/ t_hit *hit)
{
	int					objnum = sizeof(objs) / sizeof(t_object);
	constant t_object	*obj = &objs[0];
	constant t_object	*closest = NULL;
	float				closest_dist = MAXFLOAT;

	for (int i = 0; i < objnum; i++)
		intersect(&obj[i], ray_dir, ray_orig, &closest, &closest_dist, &(hit->m));
	hit->object = closest;
	if (closest && closest_dist < MAXFLOAT)
	{
		hit->pos = ray_orig + ray_dir * closest_dist;
		hit->old_dir = ray_dir;
		hit->mask *= closest->color;
		hit->normal = find_normal(closest, hit->pos, hit->m);
		if (closest->material.z > 0.0f)
			hit->material = specular;
		else if (closest->material.y > 0.0f)
			hit->material = refraction;
		else
		{
			hit->material = diffuse;
			hit->color += hit->mask * (closest->emission);
			hit->normal = dot(hit->normal, ray_dir) < 0.0f ? hit->normal : -hit->normal;
			hit->mask *= -dot(ray_dir, hit->normal);
			float3 direct = {0.f,0.f,0.f};
			for (int i = 0; i < objnum && obj->emission > 0.00001; i++)
				direct += find_direct(&obj[i], obj, objnum, hit);
			hit->color += direct * hit->mask * 0.47f;
		}
		hit->pos = hit->pos + hit->normal * 0.00003f;
	}
}

static float3	construct_ray(uint2 coords, t_camera camera, t_hit *hit)
{
	hit->color = (float3)(0, 0, 0);
	hit->mask = (float3)(1, 1, 1);
	hit->iterations = 1;
	hit->pos = camera.origin;
	return (normalize((float3)
		((((coords.x + get_random(&hit->seeds[0], &hit->seeds[1])) / camera.canvas.x) * 2 - 1) * (camera.canvas.x / camera.canvas.y),
		1 - 2 * ((coords.y + get_random(&hit->seeds[0], &hit->seeds[1])) / camera.canvas.y),
		2.0) * 0.5f
	));
}

__kernel __attribute__((vec_type_hint ( float3 )))
void	first_intersection(	/*t_scene scene,*/
							global t_hit *hits)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	t_hit	hit;
	hit.seeds[0] = mad24(coords.x, (uint)&coords, coords.y);
	hit.seeds[1] = mad24(coords.y, (uint)&coords, coords.x);
	float3	ray_dir = construct_ray(coords, camera, &hit);
	
	hit.color_accum = (float3)(0,0,0);
	hit.samples = 0;
	trace_ray(camera.origin, ray_dir, /*scene,*/ &hit);
	hits[i] = hit;
}

__kernel __attribute__((vec_type_hint ( float3 )))
void	path_tracing(	/*t_scene scene,*/
						global t_hit *hits,
						global int *image)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	float3	ray_dir;
	t_hit 	hit = hits[i];

	if (__builtin_expect(hit.iterations > 100 || !hit.object || fast_length(hit.mask) < 0.01 || fast_length(hit.color) > 1.44224957031f, false))
	{
		hit.color_accum = hit.color_accum + min(hit.color, 1.0f);
		if (fast_length(hit.color) > 0.1f)
			hit.samples++;
		if (!hit.samples)
			hit.color = hit.color_accum * 255;
		else
			hit.color = half_divide(hit.color_accum, hit.samples) * 255;
		image[i] = upsample(
				upsample((unsigned char)0,
					(unsigned char)(hit.color.x)),
				upsample((unsigned char)(hit.color.y),
					(unsigned char)(hit.color.z)));
		ray_dir = construct_ray(coords, camera, &hit);
	}
	else if (hit.material == specular)
		ray_dir = hit.old_dir - (2.0f * dot(hit.normal, hit.old_dir)) * hit.normal;
	else if (hit.material == refraction)
	{
		ray_dir = hit.old_dir - (2.0f * dot(hit.normal, hit.old_dir)) * hit.normal;
		int	into = dot(hit.normal, hit.old_dir) > 0.0f ? 1 : -1;
		float nc = 1.f;
		float nt = 1.5f;
		float nnt = into > 0.f ? nc / nt : nt / nc;
		float ddn = dot(hit.old_dir, hit.normal * into);
		float cos2t = 1.f - nnt * nnt * (1 - ddn * ddn);
		if (cos2t > 0.0f)
		{
			float kk = into * (ddn * nnt + half_sqrt(cos2t));
			float3 transDir = normalize(nnt * hit.old_dir - kk * hit.normal);
			float a = nt - nc;
			float b = nt + nc;
			float R0 = a * a / (b * b);
			float c = 1 - (into > 1 ? -ddn : dot(transDir, hit.normal));
			float Re = R0 + (1 - R0) * c * c * c * c*c;
			float Tr = 1.f - Re;
			float P = .25f + .5f * Re;
			float RP = Re / P;
			float TP = Tr / (1.f - P);

			if (get_random(&hit.seeds[0], &hit.seeds[1]) < P)
				hit.mask *= RP;
			else {
				hit.mask *= TP;
				ray_dir = transDir;
			}

		}
	}
	else
	{
		float rand1 = 2.0f * M_PI * get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2 = get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2s = half_sqrt(rand2);
		float3 w = hit.normal;
		float3 axis = fabs(w.x) > 0.1f ? (float3)(0.0f, 1.0f, 0.0f)
			: (float3)(1.0f, 0.0f, 0.0f);
		float3 u = fast_normalize(cross(axis, w));
		float3 v = cross(w, u);
		ray_dir = normalize(u * half_cos(rand1) * rand2s +
							v * half_sin(rand1) * rand2s +
							w * half_sqrt(1.0f - rand2));
	}
	trace_ray(hit.pos, ray_dir, /*scene,*/ &hit);
	hit.iterations++;
	hits[i] = hit;
}


__kernel void	smooth(global int *arr, global int *out)
{
	int i;
	int j;

	union {
		unsigned int	color;
		unsigned char	channels[4];
	} 					col[7];
	int 			win_w = camera.canvas.x;
	int				g = get_global_id(0);

	col[1].color = arr[g];
	/*
	i = g / win_w;
	col[0].color = arr[g - 1];
	col[2].color = arr[g + 1];
	col[3].color = arr[g - win_w];
	col[5].color = arr[g - win_w - 1];
	col[6].color = arr[g - win_w + 1];
	col[4].color = arr[g + win_w];
	col[7].color = arr[g + win_w + 1];
	col[8].color = arr[g + win_w - 1];
	col[1].channels[0] = (
			col[0].channels[0] +
			col[1].channels[0] +
			col[2].channels[0] +
			col[3].channels[0] +
			col[4].channels[0] +
			col[5].channels[0] +
			col[6].channels[0] +
			col[7].channels[0] +
			col[8].channels[0]) / 9;
	col[1].channels[1] = (
			col[0].channels[1] +
			col[1].channels[1] +
			col[2].channels[1] +
			col[3].channels[1] +
			col[4].channels[1] +
			col[5].channels[1] +
			col[6].channels[1] +
			col[7].channels[1] +
			col[8].channels[1]) / 9;
	col[1].channels[2] = (
			col[0].channels[2] +
			col[1].channels[2] +
			col[2].channels[2] +
			col[3].channels[2] +
			col[4].channels[2] +
			col[5].channels[2] +
			col[6].channels[2] +
			col[7].channels[2] +
			col[8].channels[2]) / 9;
	*/
	out[g] = col[1].color;
}

__kernel
void	t_hit_size(void)
{
	printf("%u\n", sizeof(t_hit));
}
