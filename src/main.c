/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/16 15:28:10 by skamoza           #+#    #+#             */
/*   Updated: 2018/03/23 16:33:29 by skamoza          ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */


#include "rt.h"

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
    rt_cl_compile(&info, "kernel.cl");
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

	window = SDL_CreateWindow("RT", 
		SDL_WINDOWPOS_CENTERED,
		SDL_WINDOWPOS_CENTERED,
		width, height, 0);

	renderer = SDL_CreateRenderer(window, -1,
		SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);

	canvas = SDL_CreateTexture( renderer,
		SDL_PIXELFORMAT_ARGB8888,
		SDL_TEXTUREACCESS_TARGET,
		width, height);

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
		//smooth(pixels, width, height);
		SDL_UpdateTexture(canvas, NULL, pixels, width << 2);
		//SDL_RenderClear(renderer);
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
