class Dip::Combination < ActiveRecord::Base
  set_table_name :dip_combination
  query_extend
  has_many :combination_header, :dependent => :destroy
  has_many :combination_record, :dependent => :destroy
  validates_presence_of :name
  validates_uniqueness_of :name

  def saveData
    connection=ActiveRecord::Base.connection.raw_connection
    connection.autocommit=false
    @list.each do |column|
      #column.save
      connection.exec(column)
    end
    connection.commit
  end

  def generate_combination_records(combinationId, header_count, items, values, i, j)
    unless @list
      @list=[]
    end
    if (items.size<header_count)
      items_new=items.clone
      items_new << values[i][j]
      generate_combination_records(combinationId, header_count, items_new, values, i+1, 0)
      if (j+1<values[i].size)
        generate_combination_records(combinationId, header_count, items, values, i, j+1)
      end
    else
      cr_id = UUID.new.generate(:compact)[1,12]
      cr_id << Time.now.to_i.to_s
      insert_records_sql="insert into dip_combination_records(id,combination_id,enabled,created_by,updated_by,created_at,updated_at)"
      insert_records_sql << " values('#{cr_id}','#{combinationId}',0,'#{Irm::Person.current.id}','#{Irm::Person.current.id}',sysdate,sysdate)"
      #logger.error   insert_records_sql
      @list << insert_records_sql
      items.each do |v|
        insert_items_sql="insert into dip_combination_items(id,combination_record_id,header_value_id,created_by,updated_by,created_at,updated_at)"
        insert_items_sql << " values('#{UUID.new.generate(:compact)[1,12]}#{Time.now.to_i.to_s}','#{cr_id}','#{v}','#{Irm::Person.current.id}','#{Irm::Person.current.id}',sysdate,sysdate)"
        @list << insert_items_sql
      end
      if @list.size >5000
        saveData
        @list=[]
      end
    end
   end
  def self.get_combination_record(valueIds, combination_id)
    combination=Dip::Combination.where({:id=>combination_id}).first
    if combination.nil?
      return nil
    end
    headers=Dip::CombinationHeader.find_by_sql("select t1.COMBINATION_ID,t1.HEADER_ID,t2.CODE,t2.\"NAME\" from DIP_COMBINATION_HEADERS t1,DIP_HEADER t2 where t1.HEADER_ID=t2.\"ID\" and t1.COMBINATION_ID='#{combination[:id]}' order by header_id")
    if valueIds.nil? || headers.size != valueIds.size
      return nil
    end
    sql = "select * from \"#{combination[:code].to_s.upcase}\" where \"ENABLED\"=1 "
    i=0
    headers.each do |h|
      sql << " and \"#{h[:code].to_s.upcase}\"='#{valueIds[i].to_s}'"
      i+=1
    end
    Dip::CombinationRecord.find_by_sql(sql).first
  end

  def self.get_enabled_combination_record(valueIds, combination_id)
    combination=Dip::Combination.where({:id=>combination_id}).first
    if combination.nil?
      return nil
    end
    headers=Dip::CombinationHeader.find_by_sql("select t1.COMBINATION_ID,t1.HEADER_ID,t2.CODE,t2.\"NAME\" from DIP_COMBINATION_HEADERS t1,DIP_HEADER t2 where t1.HEADER_ID=t2.\"ID\" and t1.COMBINATION_ID='#{combination[:id]}' order by header_id")
    if valueIds.nil? || headers.size != valueIds.size
      return nil
    end
    sql = "select * from \"#{combination[:code].to_s.upcase}\" where \"ENABLED\"=1 "
    headers.each do |h|
      sql << " and \"#{h[:code].to_s.upcase}\"='#{valueIds[h[:header_id]]}'"
    end
    Dip::CombinationRecord.find_by_sql(sql).first
  end
end
