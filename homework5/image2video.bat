ffmpeg -y -gamma 2.2 -r 20 -i src\examples\pink-room\input\beauty_%%d.exr -vcodec mpeg4 -pix_fmt yuv420p -preset slow -crf 18 pinkroom-input.mp4
ffmpeg -y -gamma 2.2 -r 20 -i src\examples\pink-room\output\result_%%d.exr -vcodec mpeg4 -pix_fmt yuv420p -preset slow -crf 18 pinkroom-result.mp4
::ffmpeg -y -gamma 2.2 -r 20 -i src\examples\box\input\beauty_%%d.exr -vcodec mpeg4 -pix_fmt yuv420p -preset slow -crf 18 box-input.mp4
:;ffmpeg -y -gamma 2.2 -r 20 -i src\examples\box\output\result_%%d.exr -vcodec mpeg4 -pix_fmt yuv420p -preset slow -crf 18 box-result.mp4
