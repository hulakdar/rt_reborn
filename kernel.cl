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
	{{1,0,0}, {1,1,1}, 1, sphere, {.sphere = {{0,17,45}, 5, 100}}},
	{{1,0,0}, {1,0,1}, 0, sphere, {.sphere = {{-8,-8,44}, 6, 100}}},
	{{1,0,0}, {1,0,1}, 0, sphere, {.sphere = {{0,0,270}, 200, 4}}},
	{{1,0,0}, {0,1,1}, 0, sphere, {.sphere = {{215,0,55}, 200, 4}}},
	{{1,0,0}, {1,1,0}, 0, sphere, {.sphere = {{-215,0,55}, 200, 100}}},
	{{1,0,0}, {1,0,0}, 0, sphere, {.sphere = {{0,215,55}, 200, 4}}},
	{{1,0,0}, {1,1,1}, 0, sphere, {.sphere = {{0,-210,55}, 200, 100}}},
	{{0,1,0}, {1,1,1}, 0, sphere, {.sphere = {{7,-5,45}, 6, 100}}},
	{{0,0,1}, {1,1,1}, 0, sphere, {.sphere = {{-8,0,55}, 7, 4}}},
	{{1,0,0}, {1,1,1}, 0, plane, {.plane = {{8,0,55}, {-1, 1, -1}}}},
	{{0,0,1}, {1,1,1}, 0, cylinder, {.cylinder = {{-8,-10,35}, {0,1,0}, 4, 16, 16}}},
	{{0,0,1}, {1,1,1}, 0, cone, {.cone = {{8,0,35}, {0,1,0}, 0.5, -7, 7}}},
	{{0,0,1}, {1,1,1}, 0, disk, {.disk = {{0,0,25}, {1, 1, 1}, 9}}}
};

static constant t_camera 	camera = {
	{0,0,0}, {0,0,1}, {1,1,1}, {500, 500}
};

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

	if ((denom = dot(ray_dir, obj->normal)) == 0)
		return (-1);
	float3	oc = ray_origin - obj->origin;
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
	float3	oc = ray_origin - obj->origin;
	float3	normal = fast_normalize(obj->normal);
	float2	z = { dot(ray_dir, normal), dot(oc, normal) };
	float	a = dot(ray_dir, ray_dir) - z.x * z.x;
	float	b = 2 * (dot(ray_dir, oc) - z.x * z.y);
	float	c = dot(oc, oc) - z.y * z.y - obj->r2;

	float2	t;
	ft_roots(&t, a, b, c);
	if ((t.x  < 0.0f) && (t.y < 0.0f))
		return (-1);
	if ((t.x  < 0.0f) || (t.y < 0.0f))
	{
		a = (t.x > t.y) ? t.x : t.y;
		*m  = z.x * a + z.y;
		return ((*m <= obj->height) && (*m >= 0) ? t.x : -1);
	}
	a = (t.x < t.y) ? t.x : t.y;
	*m  = z.x * a + z.y;
	if ((*m <= obj->height) && (*m >= 0))
		return (a);
	a = (t.x >= t.y) ? t.x : t.y;
	*m  = z.x * a + z.y;
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
	float3	oc = ray_origin - obj->origin;
	float3	normal = fast_normalize(obj->normal);
	float2	z = { dot(ray_dir, normal), dot(oc, normal) };
	float 	d = 1 + obj->half_tangent * obj->half_tangent;
	float	a = dot(ray_dir, ray_dir) - d * z.x * z.x;
	float	b = 2 * (dot(ray_dir, oc) - d * z.x * z.y);
	float	c = dot(oc, oc) - d * z.y * z.y;

	float2	t;
	ft_roots(&t, a, b, c);
	if ((t.x  < 0.0f) && (t.y < 0.0f))
		return (-1);
	if ((t.x  < 0.0f) || (t.y < 0.0f))
	{
		a = (t.x > t.y) ? t.x : t.y;
		*m  = z.x * a + z.y;
		return ((*m <= obj->m2) && (*m >= obj->m1) ? t.x : -1);
	}
	a = (t.x < t.y) ? t.x : t.y;
	*m  = z.x * a + z.y;
	if ((*m <= obj->m2) && (*m >= obj->m1))
		return (a);
	a = (t.x >= t.y) ? t.x : t.y;
	*m  = z.x * a + z.y;
	if ((*m <= obj->m2) && (*m >= obj->m1))
		return (a);
	return (-1);
}

static float3	cone_normal(constant t_cone *obj, float3 pos, float m)
{
	return (normalize(pos - obj->origin - fast_normalize(obj->normal) * m * (1 + obj->half_tangent * obj->half_tangent)));
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
	t = half_divide(-dot(oc, obj->normal), denom);
	if (t < 0)
		return (-1.0f);
	pos = (ray_origin + t * ray_dir) - obj->origin;
	if (dot(pos, pos) <= obj->radius2)
		return (t);
	return (-1);
}

static float3	disk_normal(constant t_disk *obj)
{
	return (normalize(obj->normal));
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
	const float r = half_sqrt(max(0.f, 1.f - zz * zz));
	const float xx = r * half_cos(phi);
	const float yy = r * half_sin(phi);
	float3 point = (float3)(xx, yy, zz) * (obj->radius + 0.03f);

	if (dot(point, obj->origin - hit->pos) > 0.0f)
		point = -point;
	point = point + obj->origin;
	float3 dir = point - hit->pos;
	*magnitude = fast_length(dir);
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
		hit->normal = find_normal(obj, ray_orig, hit->m);
		hit->mask *= closest->color;
		hit->color += hit->mask * (closest->emission);
		hit->normal = dot(hit->normal, ray_dir) < 0.0f ? hit->normal : -hit->normal;
		hit->mask *= -dot(ray_dir, hit->normal);
		hit->pos = hit->pos + hit->normal * 0.00003f;
		if (closest->material.z > 0.0f)
			hit->material = specular;
		else if (closest->material.y > 0.0f)
			hit->material = refraction;
		else
		{
			hit->material = diffuse;
			float3 direct = {0.f,0.f,0.f};
			for (int i = 0; i < objnum && obj->emission > 0.00001; i++)
				direct += find_direct(&obj[i], obj, objnum, hit);
			hit->color += direct * hit->mask * 0.47f;
		}
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

	if (__builtin_expect(hit.iterations > 240 || !hit.object || fast_length(hit.mask) < 0.01 || fast_length(hit.color) > 1.44224957031f, true))
	{
		hit.color_accum = hit.color_accum + min(hit.color, 1.0f);
		if (fast_length(hit.color) > 0.1f)
			hit.samples++;
		ray_dir = construct_ray(coords, camera, &hit);
	}
	else if (hit.material == specular)
		ray_dir = hit.old_dir - (2.0f * dot(hit.normal, hit.old_dir)) * hit.normal;
	/*
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
	*/
	else
	{
		float rand1 = 2.0f * M_PI * get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2 = get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2s = half_sqrt(rand2);
		float3 w = hit.normal;
		float3 axis = fabs(w.x) > 0.1f ? (float3)(0.0f, 1.0f, 0.0f)
			: (float3)(1.0f, 0.0f, 0.0f);
		float3 u = normalize(cross(axis, w));
		float3 v = cross(w, u);
		ray_dir = normalize(u * half_cos(rand1) * rand2s +
							v * half_sin(rand1) * rand2s +
							w * half_sqrt(1.0f - rand2));
	}
	trace_ray(hit.pos, ray_dir, /*scene,*/ &hit);
	hit.iterations++;
	hits[i] = hit;
}

__kernel void	draw(global t_hit *hits, global int *image)
{
	int i = get_global_id(0);
	t_hit hit = hits[i];

	if (!hit.samples)
		hit.color = hit.color_accum * 255;
	else
		hit.color = half_divide(hit.color_accum, hit.samples) * 255;
	image[i] = upsample(
			upsample((unsigned char)0,
				(unsigned char)(hit.color.x)),
			upsample((unsigned char)(hit.color.y),
				(unsigned char)(hit.color.z)));
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
	size_t				g = get_global_id(0);

	col[1].color = arr[g];
	i = g / win_w;
	if (g)
		col[0].color = arr[g - 1];
	else
		col[0].color = arr[g];
	if (g < get_global_size(0))
		col[2].color = arr[g + 1];
	else
		col[0].color = arr[g];
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
	out[g] = col[1].color;
}

__kernel
void	t_hit_size(void)
{
	printf("%u\n", sizeof(t_hit));
}
