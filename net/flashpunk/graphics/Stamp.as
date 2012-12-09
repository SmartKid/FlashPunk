package net.flashpunk.graphics 
{
	import com.adobe.utils.AGALMiniAssembler;
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.VertexBuffer3D;
	import flash.display3D.textures.Texture;
	import flash.geom.Point;
	import flash.geom.Rectangle;

	import net.flashpunk.*;

	/**
	 * A simple non-transformed, non-animated graphic.
	 */
	public class Stamp extends Graphic
	{
		/**
		 * Constructor.
		 * @param	source		Source image.
		 * @param	x			X offset.
		 * @param	y			Y offset.
		 */
		public function Stamp(source:*, x:int = 0, y:int = 0) 
		{
			// set the origin
			this.x = x;
			this.y = y;
			
			// set the graphic
			if (!source) return;
			if (source is Class) _source = FP.getBitmap(source);
			else if (source is BitmapData) _source = source;
			if (_source) _sourceRect = _source.rect;
		}
		
		/** @private Renders the Graphic. */
		override public function render(target:BitmapData, point:Point, camera:Point):void 
		{
			if (!_source) return;
			_point.x = point.x + x - camera.x * scrollX;
			_point.y = point.y + y - camera.y * scrollY;
			target.copyPixels(_source, _sourceRect, _point, null, null, true);
		}
		
		/** @private Renders the Graphic to Stage3D. */
		override public function renderStage3D(context:Context3D, point:Point, camera:Point):void
		{
			if (!_source || !context) return;
			_point.x = point.x + x - camera.x * scrollX;
			_point.y = point.y + y - camera.y * scrollY;
			
			if (_program == null) setupStage3D(context);
			if (_texture == null) createTexture(context);
			
			var vertices:Vector.<Number> = Vector.<Number>([
					_point.x,                 _point.y,                  0, 0, 0, // x, y, x, u, v
					_point.x + _source.width, _point.y,                  0, 1, 0,
					_point.x,                 _point.y + _source.height, 0, 0, 1,
					_point.x + _source.width, _point.y + _source.height, 0, 1, 1
			 	]);
			var vertexBuffer:VertexBuffer3D = context.createVertexBuffer(4, 5); // 4 vertices of 5 coordinates each
			vertexBuffer.uploadFromVector(vertices, 0, 4); // 0 offset, 4 vertices
			
			context.setVertexBufferAt(0, vertexBuffer, 0, Context3DVertexBufferFormat.FLOAT_3); // assigns XYZ coordinates to register 'va0'
			context.setVertexBufferAt(1, vertexBuffer, 3, Context3DVertexBufferFormat.FLOAT_2); // assigns UV coordinates to register 'va1'
			context.setTextureAt(0, _texture); // assigns texture to register 'fs0'
			context.setProgram(_program);
			context.setBlendFactors(Context3DBlendFactor.ONE, Context3DBlendFactor.ZERO); // reset blend mode
			context.drawTriangles(_indexBuffer);
		}
		
		/** @private Creates the index buffer and shader program. */
		private function setupStage3D(context:Context3D):void
		{
			// create index buffer
			_indexBuffer = context.createIndexBuffer(6); // 6 total vertices
			_indexBuffer.uploadFromVector(Vector.<uint>([0, 1, 2, 1, 2, 3]), 0, 6); // offset 0, 6 vertices (2 triangles)
			
			// create program
			var vertexShader:AGALMiniAssembler = new AGALMiniAssembler();
			vertexShader.assemble(
					Context3DProgramType.VERTEX,
					"mov op, va0\n" + // move XYZ coordinates to output
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
		private function createTexture(context:Context3D):void
		{
			_texture = context.createTexture(_source.width, _source.height, Context3DTextureFormat.BRGA, false);
			_texture.uploadFromBitmapData(_source);
		}
		
		/**
		 * Source BitmapData image.
		 */
		public function get source():BitmapData { return _source; }
		public function set source(value:BitmapData):void
		{
			_source = value;
			if (_source) _sourceRect = _source.rect;
			if (_texture) _texture = null; // texture will be recreated next render cycle
		}
		
		/**
		 * Width of the stamp.
		 */
		public function get width():uint { return _source.width; }
		
		/**
		 * Height of the stamp.
		 */
		public function get height():uint { return _source.height; }
		
		// Stamp information.
		/** @private */ private var _source:BitmapData;
		/** @private */ private var _sourceRect:Rectangle;
		
		// Stage3D information.
		/** @private */ private static var _program:Program3D;
		/** @private */ private static var _indexBuffer:IndexBuffer3D;
		/** @private */ private var _texture:Texture;
	}
}
