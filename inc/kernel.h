/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   kernel.h                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/22 13:31:55 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/27 11:53:56 by skamoza          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#ifndef KERNEL_H
# define KERNEL_H

# ifndef NULL
#  define NULL ((void *)0)
# endif

typedef enum	e_obj_type
{
	sphere,
	plane,
	cylinder,
	cone,
	disk,
	torus,
	triangle,
	mobius
}				t_obj_type;

typedef enum	e_material
{
	diffuse, specular, refraction
}				t_material;

typedef struct	s_sphere
{
	float3		origin;
	float		radius;
	float		r2;
}				t_sphere;

typedef struct	s_plane
{
	float3		origin;
	float3		normal;
}				t_plane;

typedef struct	s_cylinder
{
	float3		origin;
	float3		normal;
	float		radius;
	float		r2;
	float 		height;
}				t_cylinder;

typedef struct	s_cone
{
	float3		origin;
	float3		normal;
	float 		half_tangent;
	float 		m1;
	float 		m2;
}				t_cone;

typedef struct	s_disk
{
	float3		origin;
	float3		normal;
	float 		radius2;
}				t_disk;

typedef struct	s_torus
{
	float3		origin;
	float3		normal;
	float 		big_radius2;
	float 		small_radius2;
}				t_torus;

typedef struct	s_triangle
{
	float3		vertex0;
	float3		vertex1;
	float3		vertex2;
}				t_triangle;

typedef struct	s_mobius
{
	float 		radius;
	float 		half_width;
}				t_mobius;

typedef	union	u_specs
{
	t_plane		plane;
	t_sphere	sphere;
	t_cylinder	cylinder;
	t_cone		cone;
	t_disk		disk;
	t_torus		torus;
	t_triangle	triangle;
	t_mobius	mobius;
}				t_specs;

typedef struct	s_object
{
	float3		material;
	float3		color;
	float		emission;
	t_obj_type	type;
	t_specs		spec;
}				t_object;

typedef struct	s_camera
{
	float3		origin;
	float3		dir;
	float3		viewport;
	int2		canvas;
}				t_camera;

typedef struct	s_scene
{
	t_camera			camera;
	constant t_object*	objects;
	int					objects_num;
}				t_scene;

# ifdef KERNEL_ONLY
typedef struct			s_hit
{
	float3				pos;
	float3				normal;
	float 				m;
	float3				old_dir;
	float3				mask;
	float3				color;
	float3				color_accum;
	unsigned long		samples;
	constant t_object	*object;
	uint				seeds[2];
	unsigned char		iterations;
	t_material			material;
}						t_hit;
# endif

#endif
