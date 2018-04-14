/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.c                                             :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: skamoza <marvin@42.fr>                     +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2018/03/16 15:28:10 by skamoza           #+#    #+#             */
/*   Updated: 2018/04/14 15:46:40 by skamoza          ###   ########.fr       */
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
	cl_uint2		seeds = {{time(NULL), rand()}};
	t_kernel	 	primary;
	t_kernel	 	painting;
	t_kernel	 	extended;
	t_kernel	 	smooth;
	t_kernel	 	draw;
	t_kernel	 	size;
	t_scene			scene;

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

    rt_cl_init(&info);
    rt_cl_compile(&info, "kernel.cl");
	size = rt_cl_create_kernel(&info, "t_hit_size");
	primary = rt_cl_create_kernel(&info, "first_intersection");
	painting = rt_cl_create_kernel(&info, "painting");
	extended = rt_cl_create_kernel(&info, "path_tracing");
	draw = rt_cl_create_kernel(&info, "draw");
	smooth = rt_cl_create_kernel(&info, "GaussianBlur");
	cl_image_format fmt = { CL_RGB, CL_FLOAT };
	size_t pixel = 16;


	cl_mem		hits = rt_cl_malloc_read(&info, 144 * job_size);
	cl_mem		buff = rt_cl_malloc_read(&info, pixel * job_size);
	cl_mem		out = rt_cl_malloc_read(&info, sizeof(cl_int) * job_size);
	cl_image_desc desc = {
		CL_MEM_OBJECT_IMAGE2D,
		width,
		height,
		1,
		1,
		0,
		0,
		0,
		0,
		NULL
	};
	cl_image_desc tex_desc = {
		CL_MEM_OBJECT_IMAGE2D,
		4,
		2,
		1,
		1,
		0,
		0,
		0,
		0,
		NULL
	};
	cl_mem img = clCreateImage(info.context, CL_MEM_READ_WRITE, &fmt, &desc, NULL, NULL);
	cl_mem tex = clCreateImage(info.context, CL_MEM_READ_WRITE, &fmt, &tex_desc, NULL, NULL);

	clSetKernelArg(primary.kernel, 0, sizeof(t_scene), &scene);
	clSetKernelArg(primary.kernel, 1, sizeof(cl_mem), &hits);
	clSetKernelArg(primary.kernel, 2, sizeof(cl_uint2), &seeds);
	clSetKernelArg(primary.kernel, 3, sizeof(cl_mem), &tex);
	clSetKernelArg(painting.kernel, 0, sizeof(t_scene), &scene);
	clSetKernelArg(painting.kernel, 1, sizeof(cl_mem), &hits);
	clSetKernelArg(painting.kernel, 2, sizeof(cl_uint2), &seeds);
	clSetKernelArg(painting.kernel, 3, sizeof(cl_mem), &tex);
	clSetKernelArg(extended.kernel, 0, sizeof(t_scene), &scene);
	clSetKernelArg(extended.kernel, 1, sizeof(cl_mem), &hits);
	clSetKernelArg(extended.kernel, 2, sizeof(cl_mem), &tex);
	clSetKernelArg(draw.kernel, 0, sizeof(cl_mem), &hits);
	clSetKernelArg(draw.kernel, 1, sizeof(cl_mem), &img);
	clSetKernelArg(smooth.kernel, 0, sizeof(cl_mem), &img);
	clSetKernelArg(smooth.kernel, 1, sizeof(cl_mem), &out);


	//rt_cl_push_task(&painting, &job_size);
	rt_cl_push_task(&primary, &job_size);
	rt_cl_push_task(&extended, &job_size);
	rt_cl_push_task(&extended, &job_size);
	rt_cl_push_task(&extended, &job_size);
	rt_cl_push_task(&draw, &job_size);
	rt_cl_push_task(&smooth, &job_size);

	/*
	FILE *pipeout = popen("ffmpeg -y -f rawvideo -vcodec rawvideo -pix_fmt rgb32 -s 1000x1000 -r 25 -i - -f mp4 -q:v 7 -an -vcodec mpeg4 ~/tmp/output.mp4", "w");
	*/
	while (1)
	{
		if (SDL_PollEvent(&event) && (event.type == SDL_QUIT ||
		(event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)))
				break ;
		rt_cl_push_task(&extended, &job_size);
		rt_cl_push_task(&draw, &job_size);
		rt_cl_push_task(&smooth, &job_size);

		rt_cl_device_to_host(&info, out, pixels, job_size * sizeof(cl_int));
		SDL_UpdateTexture(canvas, NULL, pixels, width << 2);
		SDL_RenderCopy(renderer, canvas, NULL, NULL);
		SDL_RenderPresent(renderer);
		/*
		fwrite(pixels, 1, job_size * sizeof(cl_int), pipeout);
		*/
	}
	SDL_DestroyTexture(canvas);
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	rt_cl_free_kernel(&primary);
	rt_cl_free_kernel(&painting);
	rt_cl_free_kernel(&extended);
	rt_cl_free_kernel(&smooth);
	rt_cl_free_kernel(&draw);
	rt_cl_free_kernel(&size);
	rt_cl_free(&info);
	clReleaseMemObject(hits);
	clReleaseMemObject(buff);
	clReleaseMemObject(img);
	clReleaseMemObject(out);
	clReleaseMemObject(tex);
	/*
	fflush(pipeout);
    pclose(pipeout);
	*/
	SDL_Quit();
	return (0);
}
