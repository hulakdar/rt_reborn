/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   rt.h                                               :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/13 18:11:20 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/16 16:41:07 by skamoza          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include <stdio.h>

#ifndef RT_H
# define RT_H
# include "cl_wrap.h"
# include "SDL.h"

enum	e_obj_type
{
	sphere
};

typedef struct	s_object
{
	cl_double3	material;
	cl_double3	color;
	cl_double3	emission;
	cl_double3	origin;
	cl_double	radius;
	cl_double	r2;
	cl_int		type;
}				t_object;

typedef struct	s_camera
{
	cl_double3	origin;
	cl_double3	dir;
	cl_double3	viewport;
	cl_int2		canvas;
}				t_camera;

typedef struct	s_scene
{
	t_camera	camera;
	cl_mem		objects;
	cl_int		objects_num;
}				t_scene;

#endif
