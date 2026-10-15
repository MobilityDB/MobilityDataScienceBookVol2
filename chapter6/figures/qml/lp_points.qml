<qgis version="3.34.14-Prizren" styleCategories="AllStyleCategories" labelsEnabled="0"><renderer-v2 forceraster="0" enableorderby="0" referencescale="-1" type="singleSymbol" symbollevels="0">
        <symbols>
          <symbol force_rhr="0" is_animated="0" clip_to_extent="1" alpha="1" name="0" frame_rate="10" type="marker">
            <data_defined_properties>
              <Option type="Map">
                <Option value="" name="name" type="QString" />
                <Option name="properties" />
                <Option value="collection" name="type" type="QString" />
              </Option>
            </data_defined_properties>
            <layer locked="0" class="SimpleMarker" enabled="1" pass="0" id="{b5fd0a4e-8427-4820-a62e-1a0842392c79}">
              <Option type="Map">
                <Option value="0" name="angle" type="QString" />
                <Option value="square" name="cap_style" type="QString" />
                <Option value="225,89,137,255" name="color" type="QString" />
                <Option value="1" name="horizontal_anchor_point" type="QString" />
                <Option value="bevel" name="joinstyle" type="QString" />
                <Option value="circle" name="name" type="QString" />
                <Option value="0,0" name="offset" type="QString" />
                <Option value="3x:0,0,0,0,0,0" name="offset_map_unit_scale" type="QString" />
                <Option value="MM" name="offset_unit" type="QString" />
                <Option value="35,35,35,255" name="outline_color" type="QString" />
                <Option value="solid" name="outline_style" type="QString" />
                <Option value="0" name="outline_width" type="QString" />
                <Option value="3x:0,0,0,0,0,0" name="outline_width_map_unit_scale" type="QString" />
                <Option value="MM" name="outline_width_unit" type="QString" />
                <Option value="diameter" name="scale_method" type="QString" />
                <Option value="2" name="size" type="QString" />
                <Option value="3x:0,0,0,0,0,0" name="size_map_unit_scale" type="QString" />
                <Option value="MM" name="size_unit" type="QString" />
                <Option value="1" name="vertical_anchor_point" type="QString" />
              </Option>
              <data_defined_properties>
                <Option type="Map">
                  <Option value="" name="name" type="QString" />
                  <Option name="properties" />
                  <Option value="collection" name="type" type="QString" />
                </Option>
              </data_defined_properties>
            </layer>
          </symbol>
        </symbols>
        <rotation />
        <sizescale />
      </renderer-v2>
      <selection mode="Default">
        <selectionColor invalid="1" />
      </selection>
      <customproperties>
        <Option />
      </customproperties>
      <blendMode>0</blendMode>
      <featureBlendMode>0</featureBlendMode>
      <layerOpacity>1</layerOpacity>
      <geometryOptions removeDuplicateNodes="0" geometryPrecision="0">
        <activeChecks type="StringList">
          <Option value="" type="QString" />
        </activeChecks>
        <checkConfiguration />
      </geometryOptions>
      <fieldConfiguration>
        <field configurationFlags="NoFlag" name="tripid">
          <editWidget type="">
            <config>
              <Option />
            </config>
          </editWidget>
        </field>
        <field configurationFlags="NoFlag" name="t">
          <editWidget type="">
            <config>
              <Option />
            </config>
          </editWidget>
        </field>
        <field configurationFlags="NoFlag" name="pm25">
          <editWidget type="">
            <config>
              <Option />
            </config>
          </editWidget>
        </field>
        <field configurationFlags="NoFlag" name="weather">
          <editWidget type="">
            <config>
              <Option />
            </config>
          </editWidget>
        </field>
      </fieldConfiguration>
      <aliases>
        <alias index="0" name="" field="tripid" />
        <alias index="1" name="" field="t" />
        <alias index="2" name="" field="pm25" />
        <alias index="3" name="" field="weather" />
      </aliases>
      <defaults>
        <default expression="" applyOnUpdate="0" field="tripid" />
        <default expression="" applyOnUpdate="0" field="t" />
        <default expression="" applyOnUpdate="0" field="pm25" />
        <default expression="" applyOnUpdate="0" field="weather" />
      </defaults>
      <constraints>
        <constraint constraints="3" unique_strength="1" notnull_strength="1" exp_strength="0" field="tripid" />
        <constraint constraints="1" unique_strength="0" notnull_strength="1" exp_strength="0" field="t" />
        <constraint constraints="0" unique_strength="0" notnull_strength="0" exp_strength="0" field="pm25" />
        <constraint constraints="0" unique_strength="0" notnull_strength="0" exp_strength="0" field="weather" />
      </constraints>
      <previewExpression />
      <mapTip enabled="1" />
    </qgis>