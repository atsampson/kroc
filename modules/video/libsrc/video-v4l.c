/*
 *	video-v4l.c -- C interface to V4L2
 *	Copyright (C) 2008 Fred Barnes <frmb@kent.ac.uk>
 *
 *	This program is free software; you can redistribute it and/or modify
 *	it under the terms of the GNU General Public License as published by
 *	the Free Software Foundation; either version 2 of the License, or
 *	(at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program; if not, write to the Free Software
 *	Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <unistd.h>
#include <fcntl.h>

#include <errno.h>

#include <sys/ioctl.h>
#include <sys/mman.h>

#include <asm/types.h>
#include <linux/videodev.h>
#include <linux/videodev2.h>

#include "video-v4l.h"

#ifndef LITTLE_ENDIAN
#define LITTLE_ENDIAN
#endif

#include "ccvt.h"


static inline void video_initstruct (opi_video_device_t *dev) /*{{{*/
{
	memset (dev->fname, '0', OPI_VIDEO_DEVICE_FNAMEMAX);
	dev->fnamelen = 0;
	dev->fd = -1;
	dev->api = 0;
}
/*}}}*/
static inline int video_open (opi_video_device_t *dev) /*{{{*/
{
	if (dev->fd < 0) {
		char pbuffer[FILENAME_MAX];
		int x;

		if (dev->fnamelen >= FILENAME_MAX) {
			x = FILENAME_MAX - 1;
		} else {
			x = dev->fnamelen;
		}
		memcpy (pbuffer, dev->fname, x);
		pbuffer[x] = '\0';

		dev->fd = open (pbuffer, O_RDWR);
		if (dev->fd >= 0) {
			struct v4l2_capability v2_cap;
			struct video_capability v1_cap;
			int r;

			/* see if it's a V1 or V2 device by prodding the V2 IOCTL */
			while (((r = ioctl (dev->fd, VIDIOC_QUERYCAP, &v2_cap)) == -1) && (errno == EINTR));		/* retry */
			if (r < 0) {
				/* try V1 API */
				while (((r = ioctl (dev->fd, VIDIOCGCAP, &v1_cap)) == -1) && (errno == EINTR));		/* retry */
				if (r < 0) {
					/* not a V4L device! */
					close (dev->fd);
					dev->fd = -1;
					return 0;
				} else {
					dev->api = 1;
				}
			} else {
				dev->api = 2;
			}

			return 1;
		}
	}
	return 0;
}
/*}}}*/
static inline int video_close (opi_video_device_t *dev) /*{{{*/
{
	if (dev->fd >= 0) {
		if (close (dev->fd) == 0) {
			dev->fd = -1;
			return 1;
		}
	}
	return 0;
}
/*}}}*/

static inline int video_identity (opi_video_device_t *dev, opi_video_identity_t *ident) /*{{{*/
{
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		struct video_capability vcap;
		int r;

		while (((r = ioctl (dev->fd, VIDIOCGCAP, &vcap)) == -1) && (errno == EINTR));				/* retry */
		if (r >= 0) {
			ident->namelen = snprintf (ident->name, OPI_VIDEO_IDENTITY_NAMEMAX - 1, "%s", vcap.name);
			return 1;
		}
	} else if (dev->api == 2) {
		struct v4l2_capability v2_cap;
		int r;

		while (((r = ioctl (dev->fd, VIDIOC_QUERYCAP, &v2_cap)) == -1) && (errno == EINTR));			/* retry */
		if (r >= 0) {
			ident->namelen = snprintf (ident->name, OPI_VIDEO_IDENTITY_NAMEMAX - 1, "%s:%s:%s",
						v2_cap.driver, v2_cap.card, v2_cap.bus_info);
			return 1;
		}
	}
	return 0;
}
/*}}}*/
static inline int video_numinputs (opi_video_device_t *dev) /*{{{*/
{
	int num = 0;
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		struct video_capability vcap;
		int r;

		while (((r = ioctl (dev->fd, VIDIOCGCAP, &vcap)) == -1) && (errno == EINTR));				/* retry */
		if (r >= 0) {
			num = vcap.channels;
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
	return num;
}
/*}}}*/
static inline void video_getinputs (opi_video_device_t *dev, opi_video_input_t *inputs, int numinputs) /*{{{*/
{
	int i;
	
	/* initialise structures */
	for (i = 0; i < numinputs; ++i) {
		inputs[i].id		= -1;
		inputs[i].namelen	= 0;
		inputs[i].name[0]	= '\0';
		inputs[i].type		= 0;
		inputs[i].flags		= 0;
		inputs[i].minw		= 0;
		inputs[i].minh		= 0;
		inputs[i].maxw		= 0;
		inputs[i].maxh		= 0;
	}

	if (dev->fd < 0) {
		/* nothing */
	} else if (dev->api == 1) {
		struct video_capability vcap;
		int r;

		while (((r = ioctl (dev->fd, VIDIOCGCAP, &vcap)) == -1) && (errno == EINTR));				/* retry */
		if (r >= 0) {
			int channo = 0;

			for (i = 0; (i < vcap.channels) && (channo < numinputs); i++) {
				struct video_channel cinf;

				cinf.channel = i;
				while (((r = ioctl (dev->fd, VIDIOCGCHAN, &cinf)) == -1) && (errno == EINTR));		/* retry */
				if (r >= 0) {
					/* this one */
					inputs[channo].id = i;
					inputs[channo].namelen = snprintf (inputs[channo].name, OPI_VIDEO_INPUT_NAMEMAX, "%s", cinf.name);
					if (cinf.type == VIDEO_TYPE_TV)
						inputs[channo].type = OPI_VIDEO_TYPE_TUNER;
					else if (cinf.type == VIDEO_TYPE_CAMERA)
						inputs[channo].type = OPI_VIDEO_TYPE_CAMERA;
					if (cinf.flags & VIDEO_VC_AUDIO)
						inputs[channo].flags |= OPI_VIDEO_FLAG_AUDIO;
					inputs[channo].minw = vcap.minwidth;
					inputs[channo].minh = vcap.minheight;
					inputs[channo].maxw = vcap.maxwidth;
					inputs[channo].maxh = vcap.maxheight;

					channo++;
				}
			}
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
}
/*}}}*/
static inline int video_setinput (opi_video_device_t *dev, opi_video_input_t *input) /*{{{*/
{
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		struct video_channel cinf;
		int r;

		/* get current channel properties */
		cinf.channel = input->id;
		while (((r = ioctl (dev->fd, VIDIOCGCHAN, &cinf)) == -1) && (errno == EINTR));		/* retry */

		if ((r >= 0) && (cinf.channel == input->id)) {
			while (((r = ioctl (dev->fd, VIDIOCSCHAN, &cinf)) == -1) && (errno == EINTR));		/* retry */
			return ((r >= 0) ? 1 : 0);
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
	return 0;
}
/*}}}*/

static int pal_convert_v4l1[] = {
	OPI_VIDEO_PAL_GRAY, 	VIDEO_PALETTE_GREY,
	OPI_VIDEO_PAL_HI240, 	VIDEO_PALETTE_HI240,
	OPI_VIDEO_PAL_RGB565, 	VIDEO_PALETTE_RGB565,
	OPI_VIDEO_PAL_RGB24, 	VIDEO_PALETTE_RGB24,
	OPI_VIDEO_PAL_RGB32, 	VIDEO_PALETTE_RGB32,
	OPI_VIDEO_PAL_RGB555, 	VIDEO_PALETTE_RGB555,
	OPI_VIDEO_PAL_YUV422, 	VIDEO_PALETTE_YUV422, 
	OPI_VIDEO_PAL_YUYV, 	VIDEO_PALETTE_YUYV,
	OPI_VIDEO_PAL_YUV420P, 	VIDEO_PALETTE_YUV420P,
	OPI_VIDEO_PAL_INVALID, 	0
};

static inline int search_and_return (int *array, int stride, int search, int ret, int end, int fail, int value)
{
	int i;
	for (i = 0; array[i + search] != end; i += stride) {
		if (array[i + search] == value)
			return array[i + ret];
	}
	return fail;
}

static inline int convert_pal_opi_to_v4l1 (int v)
{
	return search_and_return (pal_convert_v4l1, 2, 0, 1, OPI_VIDEO_PAL_INVALID, 0, v);
}
static inline int convert_pal_v4l1_to_opi (int v)
{
	return search_and_return (pal_convert_v4l1, 2, 1, 0, 0, OPI_VIDEO_PAL_INVALID, v);
}

static inline void video_getpicture (opi_video_device_t *dev, struct video_picture *pict) /*{{{*/
{
	if (dev->fd < 0) {
		/* nothing */
	} else if (dev->api == 1) {
		int r;

		while (((r = ioctl (dev->fd, VIDIOCGPICT, pict)) == -1) && (errno == EINTR));		/* retry */
		pict->palette = convert_pal_v4l1_to_opi (pict->palette); 
	} else if (dev->api == 2) {
		/* FIXME! */
	}
}
/*}}}*/
static inline int video_setpicture (opi_video_device_t *dev, struct video_picture *pict) /*{{{*/
{
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		int r;

		pict->palette = convert_pal_opi_to_v4l1 (pict->palette);
		while (((r = ioctl (dev->fd, VIDIOCSPICT, pict)) == -1) && (errno == EINTR));		/* retry */
		if (r >= 0) {
			/* get the picture details again to see if we changed it */
			video_getpicture (dev, pict);
			return 1;
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
	return 0;
}
/*}}}*/
static inline void video_initio (opi_video_device_t *dev, opi_video_iodata_t *iod) /*{{{*/
{
	iod->use_mmap = -1;
	iod->mmap_addr = 0;
	iod->mmap_size = 0;
	iod->width = 0;
	iod->height = 0;
	iod->format = 0;
	iod->isize = 0;

	if (dev->fd < 0) {
		/* nothing */
	} else if (dev->api == 1) {
		struct video_mbuf vmbuf;
		struct video_window vwin;
		int r;

		vmbuf.size = 0;
		vmbuf.frames = 0;

		while (((r = ioctl (dev->fd, VIDIOCGMBUF, &vmbuf)) == -1) && (errno == EINTR));		/* retry */
		if (r >= 0) {
			/* got memory-map buffer info */
			iod->use_mmap = 1;
			iod->mmap_size = vmbuf.size;
			iod->mmap_addr = (int)mmap (NULL, iod->mmap_size, PROT_READ | PROT_WRITE, MAP_SHARED, dev->fd, 0);
			if (iod->mmap_addr == -1) {
				/* failed to mmap, default to non-mmap */
				iod->mmap_size = 0;
				iod->mmap_addr = 0;
				iod->use_mmap = 0;
			}
		} else {
			iod->use_mmap = 0;
			iod->mmap_addr = 0;
			iod->mmap_size = 0;
		}

		/* get the current window size */
		while (((r = ioctl (dev->fd, VIDIOCGWIN, &vwin)) == -1) && (errno == EINTR));		/* retry */
		if (r >= 0) {
			iod->width = vwin.width;
			iod->height = vwin.height;
		} else {
			iod->width = 0;
			iod->height = 0;
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
}
/*}}}*/
static inline void video_shutdownio (opi_video_device_t *dev, opi_video_iodata_t *iod) /*{{{*/
{
	if (dev->fd < 0) {
		/* nothing */
	} else if (iod->use_mmap < 0) {
		/* nothing */
	} else if (dev->api == 1) {
		if (iod->use_mmap) {
			munmap ((void *)iod->mmap_addr, iod->mmap_size);
			iod->mmap_addr = 0;
			iod->mmap_size = 0;
			iod->use_mmap = -1;
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
}
/*}}}*/
static inline int video_startcapture (opi_video_device_t *dev, opi_video_iodata_t *iod, opi_video_frameinfo_t *finf) /*{{{*/
{
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		if (iod->use_mmap == 1) {
			struct video_mmap vmmap;
			int r;

			vmmap.frame = 0;
			vmmap.width = finf->width;
			vmmap.height = finf->height;
			vmmap.format = finf->format;
			while (((r = ioctl (dev->fd, VIDIOCMCAPTURE, &vmmap)) == -1) && (errno == EINTR));	/* retry */
			if (r >= 0) {
				/* started capture */
				return 1;
			}
		} else {
			/* no need to do anything */
			return 1;
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
	return 0;
}
/*}}}*/
static inline int video_waitframe (opi_video_device_t *dev, opi_video_iodata_t *iod, opi_video_frameinfo_t *finf, int *buffer, int bufheight, int bufwidth) /*{{{*/
{
	if (dev->fd < 0) {
		/* not open */
	} else if (dev->api == 1) {
		if (iod->use_mmap == 1) {
			int x, y;
			int bnum = 0;
			int r;

			while (((r = ioctl (dev->fd, VIDIOCSYNC, &bnum)) == -1) && (errno == EINTR));		/* retry */
			if (r >= 0) {
				/* got a buffer-load at the mmap'd address we hope! */
				switch (finf->format) {
				case VIDEO_PALETTE_RGB24:
					ccvt_rgb24_rgb32 (finf->width, finf->height, (void *)iod->mmap_addr, (void *)buffer);
					return 1;
				default:
					break;
				}
			}
		} else {
			/* FIXME! */
		}
	} else if (dev->api == 2) {
		/* FIXME! */
	}
	return 0;
}
/*}}}*/


/*{{{  PROC ..video.initstruct (RESULT VIDEO.DEVICE vdev)*/
void _video_initstruct (int *w)			{ video_initstruct ((opi_video_device_t *)(w[0])); }
/*}}}*/
/*{{{  PROC ..video.open (VIDEO.DEVICE vdev, RESULT BOOL ok)*/
void _video_open (int *w)			{ *((int *)w[1]) = video_open ((opi_video_device_t *)(w[0])); }
/*}}}*/
/*{{{  PROC ..video.close (VIDEO.DEVICE vdev, RESULT BOOL ok)*/
void _video_close (int *w)			{ *((int *)w[1]) = video_close ((opi_video_device_t *)(w[0])); }
/*}}}*/

/*{{{  PROC ..video.identity (VIDEO.DEVICE vdev, RESULT VIDEO.IDENTITY ident, RESULT BOOL ok)*/
void _video_identity (int *w)			{ *((int *)w[2]) = video_identity ((opi_video_device_t *)(w[0]), (opi_video_identity_t *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.numinputs (VIDEO.DEVICE vdev, RESULT INT num)*/
void _video_numinputs (int *w)			{ *((int *)w[1]) = video_numinputs ((opi_video_device_t *)(w[0])); }
/*}}}*/
/*{{{  PROC ..video.getinputs (VIDEO.DEVICE vdev, []VIDEO.INPUT inputs)*/
void _video_getinputs (int *w)		{ video_getinputs ((opi_video_device_t *)(w[0]), (opi_video_input_t *)(w[1]), (int)(w[2])); }
/*}}}*/
/*{{{  PROC ..video.setinput (VIDEO.DEVICE vdev, VIDEO.INPUT input, RESULT BOOL ok)*/
void _video_setinput (int *w)			{ *((int *)w[2]) = video_setinput ((opi_video_device_t *)(w[0]), (opi_video_input_t *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.getpicture (VIDEO.DEVICE vdev, RESULT VIDEO.PICTURE picture)*/
void _video_getpicture (int *w)			{ video_getpicture ((opi_video_device_t *)(w[0]), (struct video_picture *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.setpicture (VIDEO.DEVICE vdev, VIDEO.PICTURE picture, RESULT BOOL ok)*/
void _video_setpicture (int *w)			{ *((int *)w[2]) = video_setpicture ((opi_video_device_t *)(w[0]), (struct video_picture *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.initio (VIDEO.DEVICE vdev, RESULT VIDEO.IODATA iod)*/
void _video_initio (int *w)			{ video_initio ((opi_video_device_t *)(w[0]), (opi_video_iodata_t *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.shutdownio (VIDEO.DEVICE vdev, VIDEO.IODATA iod)*/
void _video_shutdownio (int *w)			{ video_shutdownio ((opi_video_device_t *)(w[0]), (opi_video_iodata_t *)(w[1])); }
/*}}}*/
/*{{{  PROC ..video.startcapture (VIDEO.DEVICE vdev, VIDEO.IODATA iod, VIDEO.FRAMEINFO finf, RESULT BOOL ok)*/
void _video_startcapture (int *w)		{ *((int *)w[3]) = video_startcapture ((opi_video_device_t *)(w[0]), (opi_video_iodata_t *)(w[1]),
								(opi_video_frameinfo_t *)(w[2])); }
/*}}}*/
/*{{{  PROC ..video.waitframe (VIDEO.DEVICE vdev, VIDEO.IODATA iod, VIDEO.FRAMEINFO finf, [][]INT32 buffer, RESULT BOOL ok)*/
void _video_waitframe (int *w)			{ *((int *)w[6]) = video_waitframe ((opi_video_device_t *)(w[0]), (opi_video_iodata_t *)(w[1]),
								(opi_video_frameinfo_t *)(w[2]), (int *)(w[3]), (int)(w[4]), (int)(w[5])); }
/*}}}*/

