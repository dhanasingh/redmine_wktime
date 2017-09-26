class WkassetController < WkproductitemController
  unloadable
	include WktimeHelper


	# def index
	# end

	def getItemType
		'A'
	end
	
	def showAssetProperties
		true
	end

end
