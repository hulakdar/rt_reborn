
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
	constant t_object	*object;
	uint			seeds[2];
	unsigned char	iterations;
}					t_hit;

#define NULL ((void *)0)


static constant t_object	objs[] = {
	{{0,0,0}, {1,1,1}, {1,1,1}, {0,0,15}, 2, 4, 0},
	{{0,0,0}, {1,1,1}, {1,1,1}, {0,0,150}, 10, 100, 0},
	{{0,0,0}, {1,1,1}, {1,1,1}, {0,0,15}, 2, 4, 0},
	{{0,0,0}, {1,1,1}, {1,1,1}, {0,0,15}, 2, 4, 0}
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
	if (t.x < 0.0 || t.y > t.x)
		t.x = t.y;
	if (t.x < 0.0)
		return (-1);
	return (t.x);
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
	
	/*
	if (current < 0.001 || current > *closest_dist)
		return ;
		*/
		
	*closest_dist = 10;
	*closest = obj;
}

static void	trace_ray(double3 ray_orig, double3 ray_dir, t_scene scene, t_hit *hit)
{
	int				objnum = 2;
	constant t_object	*obj = &objs[0];
	constant t_object	*closest = NULL;
	double			closest_dist;

	closest_dist = INFINITY;
	for (int i = 0; i < objnum; i++)
		intersect(&obj[i], ray_dir, ray_orig, &closest, &closest_dist);
	hit->object = closest;
	if (closest)
	{
		hit->pos = ray_orig + ray_dir * closest_dist;
		hit->normal = normal(obj, ray_orig);
		hit->normal = dot(hit->normal, ray_dir) < 0.0f ? hit->normal :
			hit->normal * (-1.0f);
	}
}

static double3	construct_ray(uint2 coords, t_camera camera)
{
	return (normalize((double3)
		((((coords.x + 0.5) / camera.canvas.x) * 2 - 1) * (camera.canvas.x / camera.canvas.y),
		1 - 2 * ((coords.y + 0.5) / camera.canvas.y),
		1.0)
	));
}

__kernel __attribute__((vec_type_hint ( double3 )))
void	first_intersection(	t_scene scene,
							global t_hit *hits)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	double3	ray_dir = construct_ray(coords, camera);
	t_hit	hit;
	
	hit.color = (double3)(0, 0, 0);
	hit.iterations = 1;
	hit.seeds[0] = coords.x;
	hit.seeds[1] = coords.y;
	trace_ray(camera.origin, ray_dir, scene, &hit);
	hit.mask = (double3)(1.f, 1.f, 1.f);
	hit.color += hit.mask * hit.object->emission;
	hit.mask = hit.mask * dot(ray_dir, hit.normal);
	hits[i] = hit;
}

__kernel __attribute__((vec_type_hint ( double3 )))
void	path_tracing(	t_scene scene,
						global t_hit *hits,
						global int *image)
{
	int		i = get_global_id(0);
	uint2	coords = {i % camera.canvas.x, i / camera.canvas.x};
	t_hit 	hit = hits[i];

	if (hit.iterations > 8 || hit.object == NULL)
	{
		hit.color = min(1.0, hit.color / hit.iterations);
		image[i] += upsample(
			upsample((unsigned char)0,
					 (unsigned char)(hit.color.x * 255)),
			upsample((unsigned char)(hit.color.y * 255),
					 (unsigned char)(0)));
		return ;
	}
	float rand1 = 2.0f * M_PI * get_random(&hit.seeds[0], &hit.seeds[1]);
	float rand2 = get_random(&hit.seeds[0], &hit.seeds[1]);
	float rand2s = native_sqrt(rand2);
	double3 w = hit.normal;
	double3 axis = fabs(w.x) > 0.1f ? (double3)(0.0f, 1.0f, 0.0f)
		: (double3)(1.0f, 0.0f, 0.0f);
	double3 u = normalize(cross(axis, w));
	double3 v = cross(w, u);
	double3 ray_dir = normalize(u * native_cos(rand1) * rand2s +
						v * native_sin(rand1) * rand2s +
						w * native_sqrt(1.0f - rand2));
	trace_ray(hit.pos, ray_dir, scene, &hit);
	hit.seeds[0] = coords.x;
	hit.seeds[1] = coords.y;
	hit.iterations = hit.iterations + 1;
	hits[i] = hit;
	if (!i)
		printf("i'm in extended\n");
}

__kernel
void	t_hit_size(void)
{
	printf("%u\n", sizeof(t_hit));
}
