
typedef struct	s_object
{
	double3		material;
	double3		color;
	double3		emission;
	double3		origin;
	double		radius;
	double		r2;
	int			type;
}				t_object;

typedef struct	s_camera
{
	double3		origin;
	double3		dir;
	double3		viewport;
	int2		canvas;
}				t_camera;

typedef struct	s_scene
{
	t_camera			camera;
	constant t_object*	objects;
	int					objects_num;
}				t_scene;
typedef struct		s_hit
{
	double3			pos;
	double3			normal;
	double3			mask;
	double3			color;
	double3			color_accum;
	constant t_object	*object;
	uint			seeds[2];
	unsigned char	iterations;
	unsigned long	samples;
}					t_hit;

#define NULL ((void *)0)


static constant t_object	objs[] = {
	{{0,0,0}, {1,0,1}, {0,0,0}, {0,0,2030}, 2000, 4, 0},
	{{0,0,0}, {0,1,1}, {0,0,0}, {2015,0,15}, 2000, 4, 0},
	{{0,0,0}, {1,1,0}, {0,0,0}, {-2015,0,15}, 2000, 100, 0},
	{{0,0,0}, {1,0,0}, {0,0,0}, {0,2015,15}, 2000, 4, 0},
	{{0,0,0}, {0,0,0}, {0,0,0}, {0,-2015,15}, 2000, 100, 0},
	{{0,0,0}, {1,0.2,0.7}, {0,0,0}, {-4,0,15}, 3, 100, 0},
	{{0,0,0}, {0.5,0,0.5}, {0,0,0}, {5,0,15}, 3, 4, 0},
	{{0,0,0}, {1,1,1}, {1,1,1}, {0,25,15}, 15, 100, 0}
};

static constant t_camera 	camera = {
	{0,0,0}, {0,0,1}, {1,1,1}, {500, 500}
};

static double4	to_quaternion(double3 a)
{
	a *= 0.5;
	double3 c = native_cos(a);
	a = native_sin(a);

	return ((double4)(	c.z * c.y * c.x + a.z * a.y * a.x,
						c.z * a.y * c.x - a.z * c.y * a.x,
						c.z * c.y * a.x + a.z * a.y * c.x,
						a.z * c.y * c.x - c.z * a.y * a.x));
}

static double3	rotate_by_quaternion(double4 q, double3 vtx)
{
	return (vtx + 2.0 * cross(q.xyz, cross(q.xyz, vtx) + q.w * vtx));
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
	return (res.f - 2.0f) / 2.0f;
}

static void ft_roots(double2 *t, double a, double b, double c)
{
	double	deskr;

	deskr = b * b - 4 * a * c;
	if (deskr >= 0 && a != 0)
	{
		if (deskr == 0)
		{
			t->x = -0.5 * b / a;
			t->y = t->x;
		}
		else
		{
			t->x = (-b + sqrt(deskr)) / (2 * a);
			t->y = (-b - sqrt(deskr)) / (2 * a);
		}
	}
	else
	{
		t->x = -1;
		t->y = -1;
	}
}

static double  sphere_intersect(constant t_object *obj,
								double3 ray_dir,
								double3 ray_origin)
{
	double	a;
	double	b;
	double	c;
	double3	oc;
	double2	t;

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

static double3	normal(constant t_object *obj, double3 pos)
{
	return (normalize(pos - obj->origin));
}

static void		intersect(	constant t_object *obj,
							double3 ray_dir,
							double3 ray_orig,
							constant t_object **closest,
							double	*closest_dist)
{
	double current = sphere_intersect(obj, ray_dir, ray_orig);
	
	
	if (current < 0.0 || current > *closest_dist)
		return ;
	*closest_dist = current;
	*closest = obj;
}

static void	trace_ray(double3 ray_orig, double3 ray_dir, t_scene scene, t_hit *hit)
{
	int					objnum = sizeof(objs) / sizeof(t_object);
	constant t_object	*obj = &objs[0];
	constant t_object	*closest = NULL;
	double				closest_dist;

	closest_dist = INFINITY;
	for (int i = 0; i < objnum; i++)
		intersect(&obj[i], ray_dir, ray_orig, &closest, &closest_dist);
	hit->object = closest;
	if (closest && closest_dist < INFINITY)
	{
		hit->pos = ray_orig + ray_dir * closest_dist;
		hit->normal = normal(obj, ray_orig);
		hit->normal = dot(hit->normal, ray_dir) < 0.0f ? hit->normal :
			hit->normal * (-1.0f);
		hit->pos += hit->normal *  0.000003f;
		hit->mask *= closest->color;
		hit->color += hit->mask * closest->emission;
		hit->mask *= fabs(dot(ray_dir, hit->normal));
	}
}

static double3	construct_ray(uint2 coords, t_camera camera, t_hit *hit)
{
	hit->color = (double3)(0, 0, 0);
	hit->mask = (double3)(1, 1, 1);
	hit->iterations = 1;
	hit->pos = camera.origin;
	return (normalize((double3)
		((((coords.x + get_random(&hit->seeds[0], &hit->seeds[1])) / camera.canvas.x) * 2 - 1) * (camera.canvas.x / camera.canvas.y),
		1 - 2 * ((coords.y + get_random(&hit->seeds[0], &hit->seeds[1])) / camera.canvas.y),
		1.0)
	));
}

__kernel __attribute__((vec_type_hint ( double3 )))
void	first_intersection(	t_scene scene,
							global t_hit *hits)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	t_hit	hit;
	hit.seeds[0] += coords.x * (uint)&coords + (uint)&coords;
	hit.seeds[1] += coords.y * (uint)&coords + (uint)&coords;
	double3	ray_dir = construct_ray(coords, camera, &hit);
	
	hit.color_accum = (double3)(0,0,0);
	hit.samples = 1;
	trace_ray(camera.origin, ray_dir, scene, &hit);
	hits[i] = hit;
}

__kernel __attribute__((vec_type_hint ( double3 )))
void	path_tracing(	t_scene scene,
						global t_hit *hits,
						global int *image)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	double3	ray_dir;
	t_hit 	hit = hits[i];

	if (__builtin_expect(hit.iterations > 64 || !hit.object || fast_length(convert_float3(hit.mask)) < 0.01, 0))
	{
		hit.color_accum += min(hit.color, 1.0);
		if (fast_length(convert_float3(hit.color)) > 0.000003)
			hit.samples++;
		hit.color = (hit.color_accum / hit.samples) * 255;
		image[i] = upsample(
				upsample((unsigned char)0,
					(unsigned char)(hit.color.x)),
				upsample((unsigned char)(hit.color.y),
					(unsigned char)(hit.color.z)));
		ray_dir = construct_ray(coords, camera, &hit);
	}
	else
	{
		float rand1 = 2.0f * M_PI * get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2 = get_random(&hit.seeds[0], &hit.seeds[1]);
		float rand2s = native_sqrt(rand2);
		double3 w = hit.normal;
		double3 axis = fabs(w.x) > 0.1f ? (double3)(0.0f, 1.0f, 0.0f)
			: (double3)(1.0f, 0.0f, 0.0f);
		double3 u = normalize(cross(axis, w));
		double3 v = cross(w, u);
		ray_dir = normalize(u * native_cos(rand1) * rand2s +
				v * native_sin(rand1) * rand2s +
				w * native_sqrt(1.0f - rand2));
	}
	trace_ray(hit.pos, ray_dir, scene, &hit);
	hit.iterations++;
	hits[i] = hit;
}

__kernel
void	t_hit_size(void)
{
	printf("%u\n", sizeof(t_hit));
}
