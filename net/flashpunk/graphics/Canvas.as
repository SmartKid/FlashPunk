package net.flashpunk.graphics 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import net.flashpunk.FP;
	import net.flashpunk.Graphic;
	
	/**
	 * A  multi-purpose drawing canvas, can be sized beyond the normal Flash BitmapData limits.
	 */
	public class Canvas extends Graphic
	{
		/**
		 * Optional blend mode to use (see flash.display.BlendMode for blending modes).
		 */
		public var blend:String;
		
		/**
		 * Constructor.
		 * @param	width		Width of the canvas.
		 * @param	height		Height of the canvas.
		 */
		public function Canvas(width:uint, height:uint) 
		{
			_width = width;
			_height = height;
			_refWidth = Math.ceil(width / _maxWidth);
			_refHeight = Math.ceil(height / _maxHeight);
			_ref = new BitmapData(_refWidth, _refHeight, false, 0);
			var x:uint, y:uint, w:uint, h:uint, i:uint,
				ww:uint = _width % _maxWidth,
				hh:uint = _height % _maxHeight;
			if (!ww) ww = _maxWidth;
			if (!hh) hh = _maxHeight;
			while (y < _refHeight)
			{
				h = y < _refHeight - 1 ? _maxHeight : hh;
				while (x < _refWidth)
				{
					w = x < _refWidth - 1 ? _maxWidth : ww;
					_ref.setPixel(x, y, i);
					_buffers[i] = new BitmapData(w, h, true, 0);
					i ++; x ++;
				}
				x = 0; y ++;
			}
		}
		
		/** @private Renders the canvas. */
		override public function render(target:BitmapData, point:Point, camera:Point):void 
		{
			// determine drawing location
			_point.x = point.x + x - camera.x * scrollX;
			_point.y = point.y + y - camera.y * scrollY;
			
			// render the buffers
			var xx:int, yy:int, buffer:BitmapData, px:Number = _point.x;
			while (yy < _refHeight)
			{
				while (xx < _refWidth)
				{
					buffer = _buffers[_ref.getPixel(xx, yy)];
					if (_tint || blend)
					{
						_matrix.identity();
						_matrix.tx = _point.x;
						_matrix.ty = _point.y;
						_bitmap.bitmapData = buffer;
						target.draw(_bitmap, _matrix, _tint, blend);
					}
					else target.copyPixels(buffer, buffer.rect, _point, null, null, true);
					_point.x += _maxWidth;
					xx ++;
				}
				_point.x = px;
				_point.y += _maxHeight;
				xx = 0;
				yy ++;
			}
		}
		
		/** @private Renders the canvas to Stage3D. */
		override public function renderStage3D(context:Context3D, point:Point, camera:Point):void
		{
			if (!_buffers || !context) return;
			_point.x = point.x + x - camera.x * scrollX;
			_point.y = point.y + y - camera.y * scrollY;
			
			if (_program == null) setupStage3D(context);
			if (_textures == null) createTextures(context);
			
			var vertices:Vector.<Number>
			var vertexBuffer:VertexBuffer3D = context.createVertexBuffer(4, 5); // 4 vertices of 5 coordinates each
			
			var matrix:Matrix3D = new Matrix3D(Vector.<Number>([
				scaleX * scale, 0, 0, -originX * scaleX * scale,
				0, scaleY * scale, 0, -originY * scaleY * scale,
				0, 0, 1, 0,
				0, 0, 0, 1
			]));
			if (angle != 0) matrix.appendRotation(angle * FP.RAD, Vector3D.Z_AXIS);
			matrix.appendTranslation(originX + _point.x, originY + _point.y, 0);
			context.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, matrix, true); // assigns matrix to registers 'vc0' through 'vc3'
			
			switch (blend)
			{
				case BlendMode.ALPHA:
					context.setBlendFactors(Context3DBlendFactor.ZERO, Context3DBlendFactor.SOURCE_ALPHA);
					break;
				case BlendMode.ERASE:
					context.setBlendFactors(Context3DBlendFactor.ZERO, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
					break;
				case BlendMode.ADD:
					context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.DESTINATION_ALPHA);
					break;
				case BlendMode.MULTIPLY:
					context.setBlendFactors(Context3DBlendFactor.DESTINATION_COLOR, Context3DBlendFactor.ZERO);
					break;
				case BlendMode.SCREEN:
					context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE);
					break;
				case BlendMode.NORMAL:
					context.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
					break;
				default:
					if (blend) {
						if (FP.console) FP.console.log("The blend mode '" + blend + "' does not work with Stage3D rendering.");
						else trace("The blend mode '" + blend + "' does not work with Stage3D rendering.");
					}
					context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO);
					break;
			}
			
			context.setProgram(_program);
			
			// draw each buffer
			var i:int, buffer:BitmapData;
			var minX:int = _point.x;
			for (var yy:int = 0; yy < _refHeight; ++yy)
			{
				for (var xx:int = 0; xx < _refWidth; ++xx)
				{
					i = _ref.getPixel(xx, yy); // gets current index
					buffer = _buffers[i]; // gets current buffer
					
					vertices = Vector.<Number>([
						_point.x,                _point.y,                 0, 0, 0, // x, y, x, u, v
						_point.x + buffer.width, _point.y,                 0, 1, 0,
						_point.x,                _point.y + buffer.height, 0, 0, 1,
						_point.x + buffer.width, _point.y + buffer.height, 0, 1, 1
					]);
					vertexBuffer.uploadFromVector(vertices, 0, 4); // 0 offset, 4 vertices
					context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3); // assigns XYZ coordinates to register 'va0'
					context.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2); // assigns UV coordinates to register 'va1'
					
					context.setTextureAt(0, _textures[i]); // assigns current texture to register 'fs0'
					
					context.drawTriangles(_indexBuffer);
					
					_point.x += _maxWidth;
				}
				_point.x = minX;
				_point.y += _maxHeight;
			}
		}
		
		/** @private Creates the index buffer and shader program. */
		protected function setupStage3D(context:Context3D):void
		{
			// create index buffer
			_indexBuffer = context.createIndexBuffer(6);
			_indexBuffer.uploadFromVector(Vector.<uint>([0, 1, 2, 1, 2, 3]), 0, 6);
			
			// create program
			var vertexShader:AGALMiniAssembler = new AGALMiniAssembler();
			vertexShader.assemble(
				Context3DProgramType.VERTEX,
				"m44 op, va0, vc0\n" + // transform XYZ coordinates using passed-in matrix and store result in output
				"mov v0, va1" // pass UV coordinates to fragment shader
			);
			var fragmentShader:AGALMiniAssembler = new AGALMiniAssembler();
			fragmentShader.assemble(
				Context3DProgramType.FRAGMENT,
				"tex oc, v0, fs0 <2d,linear,nomip,wrap>" // use UV coordinates to create texture and store result in output
			);
			_program = context.createProgram();
			_program.upload(vertexShader.agalcode, fragmentShader.agalcode);
		}
		
		/** @private Creates the Stage3D texture. */
		protected function createTextures(context:Context3D):void
		{
			// create array of textures
			_textures = new Vector.<Texture>(_refWidth * _refHeight, true);
			// convert buffers to textures
			var buffer:BitmapData, texture:Texture, i:int;
			for (var yy:int = 0; yy < _refHeight; ++yy)
			{
				for (var xx:int = 0; xx < _refWidth; ++xx)
				{
					i = _ref.getPixel(xx, yy); // gets current index
					buffer = _buffers[i]; // gets current buffer
					texture = _textures[i]; // gets current texture
					texture = context.createTexture(buffer.width, buffer.height, Context3DTextureFormat.BRGA, false);
					texture.uploadFromBitmapData(buffer);
				}
			}
		}
		
		/**
		 * Draws to the canvas.
		 * @param	x			X position to draw.
		 * @param	y			Y position to draw.
		 * @param	source		Source BitmapData.
		 * @param	rect		Optional area of the source image to draw from. If null, the entire BitmapData will be drawn.
		 */
		public function draw(x:int, y:int, source:BitmapData, rect:Rectangle = null):void
		{
			_textures = null;
			
			var xx:int, yy:int;
			for each (var buffer:BitmapData in _buffers)
			{
				_point.x = x - xx;
				_point.y = y - yy;
				buffer.copyPixels(source, rect ? rect : source.rect, _point, null, null, true);
				xx += _maxWidth;
				if (xx >= _width)
				{
					xx = 0;
					yy += _maxHeight;
				}
			}
		}
		
		/**
		 * Mimics BitmapData's copyPixels method.
		 * @param	source			Source BitmapData.
		 * @param	rect			Area of the source image to draw from.
		 * @param	destPoint		Position to draw at.
		 * @param	alphaBitmapData	See BitmapData documentation for details.
		 * @param	alphaPoint		See BitmapData documentation for details.
		 * @param	mergeAlpha		See BitmapData documentation for details.
		 */
		public function copyPixels(source:BitmapData, rect:Rectangle, destPoint:Point, alphaBitmapData:BitmapData = null, alphaPoint:Point = null, mergeAlpha:Boolean = false):void
		{
			_textures = null;
			
			var destX:int = destPoint.x;
			var destY:int = destPoint.y;
			
			var ix1:int = uint(destPoint.x / _maxWidth);
			var iy1:int = uint(destPoint.y / _maxHeight);
			
			var ix2:int = uint((destPoint.x + rect.width) / _maxWidth);
			var iy2:int = uint((destPoint.y + rect.height) / _maxHeight);
			
			if (ix1 < 0) ix1 = 0;
			if (iy1 < 0) iy1 = 0;
			if (ix2 >= _refWidth) ix2 = _refWidth - 1;
			if (iy2 >= _refHeight) iy2 = _refHeight - 1;
			
			for (var ix:int = ix1; ix <= ix2; ix++) {
				for (var iy:int = iy1; iy <= iy2; iy++) {
					var buffer:BitmapData = _buffers[_ref.getPixel(ix, iy)];
					
					_point.x = destX - ix*_maxWidth;
					_point.y = destY - iy*_maxHeight;
			
					buffer.copyPixels(source, rect, _point, alphaBitmapData, alphaPoint, mergeAlpha);
				}
			}
					
		}
		
		/**
		 * Fills the rectangular area of the canvas. The previous contents of that area are completely removed.
		 * @param	rect		Fill rectangle.
		 * @param	color		Fill color.
		 * @param	alpha		Fill alpha.
		 */
		public function fill(rect:Rectangle, color:uint = 0, alpha:Number = 1):void
		{
			_textures = null;
			
			var xx:int, yy:int, buffer:BitmapData;
			_rect.width = rect.width;
			_rect.height = rect.height;
			if (alpha >= 1) color |= 0xFF000000;
			else if (alpha <= 0) color = 0;
			else color = (uint(alpha * 255) << 24) | (0xFFFFFF & color);
			for each (buffer in _buffers)
			{
				_rect.x = rect.x - xx;
				_rect.y = rect.y - yy;
				buffer.fillRect(_rect, color);
				xx += _maxWidth;
				if (xx >= _width)
				{
					xx = 0;
					yy += _maxHeight;
				}
			}
		}
		
		/**
		 * Draws over a rectangular area of the canvas.
		 * @param	rect		Drawing rectangle.
		 * @param	color		Draw color.
		 * @param	alpha		Draw alpha. If < 1, this rectangle will blend with existing contents of the canvas.
		 */
		public function drawRect(rect:Rectangle, color:uint = 0, alpha:Number = 1):void
		{
			_textures = null;
			
			var xx:int, yy:int, buffer:BitmapData;
			if (alpha >= 1)
			{
				_rect.width = rect.width;
				_rect.height = rect.height;
				
				for each (buffer in _buffers)
				{
					_rect.x = rect.x - xx;
					_rect.y = rect.y - yy;
					buffer.fillRect(_rect, 0xFF000000 | color);
					xx += _maxWidth;
					if (xx >= _width)
					{
						xx = 0;
						yy += _maxHeight;
					}
				}
				return;
			}
			for each (buffer in _buffers)
			{
				_graphics.clear();
				_graphics.beginFill(color, alpha);
				_graphics.drawRect(rect.x - xx, rect.y - yy, rect.width, rect.height);
				buffer.draw(FP.sprite);
				xx += _maxWidth;
				if (xx >= _width)
				{
					xx = 0;
					yy += _maxHeight;
				}
			}
			_graphics.endFill();
		}
		
		/**
		 * Fills the rectangle area of the canvas with the texture.
		 * @param	rect		Fill rectangle.
		 * @param	texture		Fill texture.
		 */
		public function fillTexture(rect:Rectangle, texture:BitmapData):void
		{
			_textures = null;
			
			var xx:int, yy:int;
			for each (var buffer:BitmapData in _buffers)
			{
				_graphics.clear();
				_matrix.identity();
				_matrix.translate(rect.x - xx, rect.y - yy);
				_graphics.beginBitmapFill(texture, _matrix);
				_graphics.drawRect(rect.x - xx, rect.y - yy, rect.width, rect.height);
				buffer.draw(FP.sprite);
				xx += _maxWidth;
				if (xx >= _width)
				{
					xx = 0;
					yy += _maxHeight;
				}
			}
			_graphics.endFill();
		}
		
		/**
		 * Draws the Graphic object to the canvas.
		 * @param	x			X position to draw.
		 * @param	y			Y position to draw.
		 * @param	source		Graphic to draw.
		 */
		public function drawGraphic(x:int, y:int, source:Graphic):void
		{
			_textures = null;
			
			var xx:int, yy:int;
			for each (var buffer:BitmapData in _buffers)
			{
				_point.x = x - xx;
				_point.y = y - yy;
				source.render(buffer, _point, FP.zero);
				xx += _maxWidth;
				if (xx >= _width)
				{
					xx = 0;
					yy += _maxHeight;
				}
			}
		}
		
		public function getPixel (x:int, y:int):uint
		{
			var buffer:BitmapData = _buffers[_ref.getPixel(x / _maxWidth, y / _maxHeight)];
			
			x %= _maxWidth;
			y %= _maxHeight;
			
			return buffer.getPixel32(x, y);
		}
		
		public function setPixel (x:int, y:int, color:uint):void
		{
			_textures = null;
			
			var buffer:BitmapData = _buffers[_ref.getPixel(x / _maxWidth, y / _maxHeight)];
			
			x %= _maxWidth;
			y %= _maxHeight;
			
			buffer.setPixel32(x, y, color);
		}
		
		/**
		 * The tinted color of the Canvas. Use 0xFFFFFF to draw the it normally.
		 */
		public function get color():uint { return _color; }
		public function set color(value:uint):void
		{
			value &= 0xFFFFFF;
			if (_color == value) return;
			_color = value;
			if (_alpha == 1 && _color == 0xFFFFFF)
			{
				_tint = null;
				return;
			}
			_tint = _colorTransform;
			_tint.redMultiplier = (_color >> 16 & 0xFF) / 255;
			_tint.greenMultiplier = (_color >> 8 & 0xFF) / 255;
			_tint.blueMultiplier = (_color & 0xFF) / 255;
			_tint.alphaMultiplier = _alpha;
			
			_textures = null;
		}
		
		/**
		 * Change the opacity of the Canvas, a value from 0 to 1.
		 */
		public function get alpha():Number { return _alpha; }
		public function set alpha(value:Number):void
		{
			if (value < 0) value = 0;
			if (value > 1) value = 1;
			if (_alpha == value) return;
			_alpha = value;
			if (_alpha == 1 && _color == 0xFFFFFF)
			{
				_tint = null;
				return;
			}
			_tint = _colorTransform;
			_tint.redMultiplier = (_color >> 16 & 0xFF) / 255;
			_tint.greenMultiplier = (_color >> 8 & 0xFF) / 255;
			_tint.blueMultiplier = (_color & 0xFF) / 255;
			_tint.alphaMultiplier = _alpha;
			
			_textures = null;
		}
		
		/**
		 * Shifts the canvas' pixels by the offset.
		 * @param	x	Horizontal shift.
		 * @param	y	Vertical shift.
		 */
		public function shift(x:int = 0, y:int = 0):void
		{
			drawGraphic(x, y, this);
		}
		
		/**
		 * Width of the canvas.
		 */
		public function get width():uint { return _width; }
		
		/**
		 * Height of the canvas.
		 */
		public function get height():uint { return _height; }
		
		// Buffer information.
		/** @private */ private var _buffers:Vector.<BitmapData> = new Vector.<BitmapData>;
		/** @private */ protected var _width:uint;
		/** @private */ protected var _height:uint;
		/** @private */ protected var _maxWidth:uint = 2880;
		/** @private */ protected var _maxHeight:uint = 2880;
		/** @private */ protected var _bitmap:Bitmap = new Bitmap;
		
		// Color tinting information.
		/** @private */ private var _color:uint = 0xFFFFFF;
		/** @private */ private var _alpha:Number = 1;
		/** @private */ private var _tint:ColorTransform;
		/** @private */ private var _colorTransform:ColorTransform = new ColorTransform;
		/** @private */ private var _matrix:Matrix = new Matrix;
		
		// Canvas reference information.
		/** @private */ private var _ref:BitmapData;
		/** @private */ private var _refWidth:uint;
		/** @private */ private var _refHeight:uint;
		
		// Global objects.
		/** @private */ private var _rect:Rectangle = new Rectangle;
		/** @private */ private var _graphics:Graphics = FP.sprite.graphics;
		
		// Stage3D information.
		/** @private */ private static var _program:Program3D;
		/** @private */ private static var _indexBuffer:IndexBuffer3D;
		/** @private */ private var _textures:Vector.<Texture>;
	}
}
