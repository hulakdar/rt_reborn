/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/16 15:28:10 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/21 18:26:50 by skamoza          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */


#include "rt.h"


union    u_color
{
	 unsigned int color;
	  unsigned char channels[4];
};

void smooth(int *addr, int win_w, int win_h)
{
	int i;
	int j;
	int *new;
	int arr[win_w][win_h];
	union    u_color col[9];

	i = 0;
	new = addr;
	while (i < win_w)
	{
		j = 0;
		while (j < win_h)
		{
			arr[i][j] = *new;
			new++;
			j++;
		}
		i++;
	}
	i = 1;
	while (i < win_w - 1)
	{
		j = 1;
		while (j < win_h - 1)
		{
			col[0].color = arr[i][j - 1];
			col[1].color = arr[i][j];
			col[2].color = arr[i][j + 1];
			col[3].color = arr[i - 1][j];
			col[4].color = arr[i + 1][j];
			/*
			col[5].color = arr[i - 1][j - 1];
			col[6].color = arr[i - 1][j + 1];
			col[7].color = arr[i + 1][j - 1];
			col[8].color = arr[i + 1][j + 1];
			*/
			col[1].channels[0] = (col[0].channels[0] + col[1].channels[0] + col[2].channels[0] + col[3].channels[0] + col[4].channels[0]) / 5;
			col[1].channels[1] = (col[0].channels[1] + col[1].channels[1] + col[2].channels[1] + col[3].channels[1] + col[4].channels[1]) / 5;
			col[1].channels[2] = (col[0].channels[2] + col[1].channels[2] + col[2].channels[2] + col[3].channels[2] + col[4].channels[2]) / 5;
			arr[i][j] = col[1].color;
			j++;
		}
		i++;
	}
	i = 1;
	while (i < win_w - 1)
	{
		j = 1;
		while (j < win_h - 1)
		{
			col[0].color = arr[i][j - 1];
			col[1].color = arr[i][j];
			col[2].color = arr[i][j + 1];
			col[3].color = arr[i - 1][j];
			col[4].color = arr[i + 1][j];
			col[5].color = arr[i - 1][j - 1];
			col[6].color = arr[i - 1][j + 1];
			col[7].color = arr[i + 1][j - 1];
			col[8].color = arr[i + 1][j + 1];
			col[1].channels[0] = (col[0].channels[0] + col[1].channels[0] + col[2].channels[0] + col[3].channels[0] + col[4].channels[0] + col[5].channels[0] + col[6].channels[0] + col[7].channels[0] + col[8].channels[0]) / 9;
			col[1].channels[1] = (col[0].channels[1] + col[1].channels[1] + col[2].channels[1] + col[3].channels[1] + col[4].channels[1] + col[5].channels[1] + col[6].channels[1] + col[7].channels[1] + col[8].channels[1]) / 9;
			col[1].channels[2] = (col[0].channels[2] + col[1].channels[2] + col[2].channels[2] + col[3].channels[2] + col[4].channels[2] + col[5].channels[2] + col[6].channels[2] + col[7].channels[2] + col[8].channels[2]) / 9;
			arr[i][j] = col[1].color;
			j++;
		}
		i++;
	}
	i = 0;
	new = addr;
	while (i < win_w)
	{
		j = 0;
		while (j < win_h)
		{
			*new = arr[i][j];
			new++;
			j++;
		}
		i++;
	}
}

int main(void)
{
	SDL_Window		*window;
	SDL_Renderer	*renderer;
	SDL_Texture		*canvas;
	const int		width = 1000;
	const int		height = 1000;
	size_t			job_size = width * height;
	cl_int			pixels[job_size];
	t_cl_info		info;
	t_kernel	 	primary;
	t_kernel	 	extended;
	t_kernel	 	smooth;
	t_kernel	 	size;
	t_scene			scene;

    rt_cl_init(&info);
    rt_cl_compile(&info, (char *)noc_file_dialog_open(1, NULL, "."));
	size = rt_cl_create_kernel(&info, "t_hit_size");
	primary = rt_cl_create_kernel(&info, "first_intersection");
	extended = rt_cl_create_kernel(&info, "path_tracing");
	smooth = rt_cl_create_kernel(&info, "smooth");

	cl_mem	hits = rt_cl_malloc_read(&info, 256 * job_size);
	cl_mem	buff = rt_cl_malloc_read(&info, sizeof(cl_int) * job_size);
	cl_mem	out = rt_cl_malloc_read(&info, sizeof(cl_int) * job_size);
	clSetKernelArg(primary.kernel, 0, sizeof(t_scene), &scene);
	clSetKernelArg(primary.kernel, 1, sizeof(cl_mem), &hits);
	clSetKernelArg(extended.kernel, 0, sizeof(t_scene), &scene);
	clSetKernelArg(extended.kernel, 1, sizeof(cl_mem), &hits);
	clSetKernelArg(extended.kernel, 2, sizeof(cl_mem), &buff);
	clSetKernelArg(smooth.kernel, 0, sizeof(cl_mem), &buff);
	clSetKernelArg(smooth.kernel, 1, sizeof(cl_mem), &out);
	rt_cl_push_task(&primary, &job_size);
	rt_cl_push_task(&extended, &job_size);
	rt_cl_push_task(&extended, &job_size);
	rt_cl_push_task(&extended, &job_size);

	rt_cl_join(&info);

	SDL_Init(SDL_INIT_VIDEO);

	window = SDL_CreateWindow(
		"RT", 
		SDL_WINDOWPOS_CENTERED,
		SDL_WINDOWPOS_CENTERED,
		width,
		height,
		0);

	renderer = SDL_CreateRenderer(
		window,
		-1,
		SDL_RENDERER_ACCELERATED);

	canvas = SDL_CreateTexture(
		renderer,
		SDL_PIXELFORMAT_ARGB8888,
		SDL_TEXTUREACCESS_TARGET,
		width,
		height);

	SDL_Event		event;
	bzero(pixels, sizeof(pixels));
	while (1)
	{
		if (SDL_PollEvent(&event) && (event.type == SDL_QUIT || (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)))
				break ;
		for (int i = 0; i < 20; i++)
			rt_cl_push_task(&extended, &job_size);

	rt_cl_push_task(&smooth, &job_size);
	rt_cl_device_to_host(&info, out, pixels, job_size * sizeof(int));
		rt_cl_join(&info);
		/*
		smooth(pixels, width, height);
		*/
		SDL_UpdateTexture(canvas, NULL, pixels, width << 2);
		SDL_RenderClear(renderer);
		SDL_RenderCopy(renderer, canvas, NULL, NULL);
		SDL_RenderPresent(renderer);
	}
	SDL_DestroyTexture(canvas);
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	rt_cl_free_kernel(&primary);
	rt_cl_free_kernel(&extended);
	rt_cl_free_kernel(&size);
	rt_cl_free(&info);
	clReleaseMemObject(hits);
	clReleaseMemObject(buff);
	SDL_Quit();
	return (0);
}
