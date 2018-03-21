/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   rt.h                                               :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/13 18:11:20 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/21 18:26:51 by skamoza          ###   ########.fr       */
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
enum {
    NOC_FILE_DIALOG_OPEN    = 1 << 0,   // Create an open file dialog.
    NOC_FILE_DIALOG_SAVE    = 1 << 1,   // Create a save file dialog.
    NOC_FILE_DIALOG_DIR     = 1 << 2,   // Open a directory.
    NOC_FILE_DIALOG_OVERWRITE_CONFIRMATION = 1 << 3,
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

const char *noc_file_dialog_open(int flags,
                                 const char *filters,
                                 const char *default_path);
#endif
